# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-imy-bin/helpers/framework.rb'
require 'English'
require 'cocoapods-imy-bin/config/config_builder'
require 'shellwords'

module CBin
  class Framework
    class Builder
      include Pod
#Debug下还待完成
      def initialize(spec, file_accessor, platform, source_dir, isRootSpec = true, build_model="Release")
        @spec = spec
        @source_dir = source_dir
        @file_accessor = file_accessor
        @platform = platform
        @build_model = build_model
        @isRootSpec = isRootSpec
        #vendored_static_frameworks 只有 xx.framework  需要拼接为 xx.framework/xx by slj
        vendored_static_frameworks = file_accessor.vendored_static_frameworks.map do |framework|
          path = framework
          extn = File.extname  path
          if extn.downcase == '.framework'
            path = File.join(path,File.basename(path, extn))
          end
          path
        end

        @vendored_libraries = (vendored_static_frameworks + file_accessor.vendored_static_libraries).map(&:to_s)
      end

      def build
        defines = compile
        build_sim_libraries(defines)

        defines
      end

      def lipo_build(defines)
        UI.section("Building static framework #{@spec}") do
          # defines = compile

          # build_sim_libraries(defines)
          output = framework.versions_path + Pathname.new(@spec.name)

          build_static_library_for_ios(output)

          copy_headers
          copy_license
          copy_resources

          cp_to_source_dir
        end
        framework
      end

      private

      def cp_to_source_dir
        framework_name = "#{@spec.name}.framework"
        target_dir = File.join(CBin::Config::Builder.instance.zip_dir,framework_name)
        FileUtils.rm_rf(target_dir) if File.exist?(target_dir)

        zip_dir = CBin::Config::Builder.instance.zip_dir
        FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)

        `cp -fa #{@platform}/#{framework_name} #{target_dir}`
      end

      def build_sim_libraries(defines)
        UI.message 'Building simulator libraries'

        if is_debug_model
          # archs = %w[i386 x86_64]
          archs = %w[x86_64]
          archs.map do |arch|
            xcodebuild(defines, "-sdk iphonesimulator ARCHS=\'#{arch}\' ", "build-#{arch}","Debug")
          end
        else
          xcodebuild(defines, "-sdk iphonesimulator ", 'build-simulator')
        end

      end

      def copy_headers
        #走 podsepc中的public_headers
        public_headers = Array.new

        #by slj 如果没有头文件，去 "Headers/Public"拿
        # if public_headers.empty?
          Dir.chdir("./Headers/Public/#{@spec.name}") do
            headers = Dir.glob('*.h')
            headers.each do |h|
              public_headers << Pathname.new(File.join(Dir.pwd,h))
            end
          end
        # end

        # UI.message "Copying public headers #{public_headers.map(&:basename).map(&:to_s)}"

        public_headers.each do |h|
          `ditto #{h} #{framework.headers_path}/#{h.basename}`
        end

        # If custom 'module_map' is specified add it to the framework distribution
        # otherwise check if a header exists that is equal to 'spec.name', if so
        # create a default 'module_map' one using it.
        if !@spec.module_map.nil?
          module_map_file = @file_accessor.module_map
          if Pathname(module_map_file).exist?
            module_map = File.read(module_map_file)
         end
        elsif public_headers.map(&:basename).map(&:to_s).include?("#{@spec.name}.h")
          module_map = <<-MAP
          framework module #{@spec.name} {
            umbrella header "#{@spec.name}.h"

            export *
            module * { export * }
          }
          MAP
        end

        unless module_map.nil?
          UI.message "Writing module map #{module_map}"
          unless framework.module_map_path.exist?
            framework.module_map_path.mkpath
         end
          File.write("#{framework.module_map_path}/module.modulemap", module_map)
        end
      end

      def copy_license
        UI.message 'Copying license'
        license_file = @spec.license[:file] || 'LICENSE'
        `cp "#{license_file}" .` if Pathname(license_file).exist?
      end

      def copy_resources

        bundles = Dir.glob('./build/*.bundle')

        bundle_names = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
          consumer = spec.consumer(@platform)
          consumer.resource_bundles.keys +
              consumer.resources.map do |r|
                File.basename(r, '.bundle') if File.extname(r) == 'bundle'
              end
        end.compact.uniq

        bundles.select! do |bundle|
          bundle_name = File.basename(bundle, '.bundle')
          bundle_names.include?(bundle_name)
        end

        if bundles.count > 0
          UI.message "Copying bundle files #{bundles}"
          bundle_files = bundles.join(' ')
          `cp -rp #{bundle_files} #{framework.resources_path} 2>&1`
        end

        real_source_dir = @isRootSpec ? @source_dir : Pathname.new(File.join(Dir.pwd,"#{@spec.name}"))
        resources = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
          expand_paths(real_source_dir, spec.consumer(@platform).resources)
        end.compact.uniq

        if resources.count == 0 && bundles.count == 0
          framework.delete_resources
          return
        end

        if resources.count > 0
          #把 路径转义。 避免空格情况下拷贝失败
          escape_resource = []
           resources.each do |source|
             escape_resource << Shellwords.join(source)
          end
          UI.message "Copying resources #{escape_resource}"
          `cp -rp #{escape_resource.join(' ')} #{framework.resources_path}`
        end
      end

      def static_libs_in_sandbox(build_dir = 'build')
        file = Dir.glob("#{build_dir}/lib#{target_name}.a")
        unless file
          UI.warn "file no find = #{build_dir}/lib#{target_name}.a"
        end
        file
      end

      def build_static_library_for_ios(output)
        UI.message "Building ios libraries with archs #{ios_architectures}"
        static_libs = static_libs_in_sandbox('build') + static_libs_in_sandbox('build-simulator') + @vendored_libraries
        if is_debug_model
          ios_architectures.map do |arch|
            static_libs += static_libs_in_sandbox("build-#{arch}") + static_libs_in_sandbox('build-simulator') + @vendored_libraries
          end
        end

        build_path = Pathname("build")
        build_path.mkpath unless build_path.exist?

        libs = ios_architectures.map do |arch|
          library = "build/package-#{@spec.name}-#{arch}.a"
          # libtool -arch_only arm64 -static -o build/package-armv64.a build/libIMYFoundation.a build-simulator/libIMYFoundation.a
          # 从liBFoundation.a 文件中，提取出 arm64 架构的文件，命名为build/package-armv64.a
          UI.message "libtool -arch_only #{arch} -static -o #{library} #{static_libs.join(' ')}"
          `libtool -arch_only #{arch} -static -o #{library} #{static_libs.join(' ')}`
          library
        end
        UI.message "lipo -create -output #{output} #{libs.join(' ')}"
        `lipo -create -output #{output} #{libs.join(' ')}`
      end

      def ios_build_options
        "ARCHS=\'#{ios_architectures.join(' ')}\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'"
      end

      def ios_architectures
        # >armv7
        #   iPhone4
        #   iPhone4S
        # >armv7s   去掉
        #   iPhone5
        #   iPhone5C
        # >arm64
        #   iPhone5S(以上)
        # >i386
        #   iphone5,iphone5s以下的模拟器
        # >x86_64
        #   iphone6以上的模拟器
        archs = %w[x86_64 arm64 armv7]
        # archs = %w[x86_64 arm64 armv7s i386]
        @vendored_libraries.each do |library|
          archs = `lipo -info #{library}`.split & archs
        end
        archs
      end

      def compile
        defines = "GCC_PREPROCESSOR_DEFINITIONS='$(inherited)'"
        defines += ' '
        defines += @spec.consumer(@platform).compiler_flags.join(' ')

        options = ios_build_options
        if is_debug_model
          archs = %w[arm64 armv7]
          # archs = %w[arm64 armv7 armv7s]
          archs.map do |arch|
            xcodebuild(defines, "ARCHS=\'#{arch}\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'","build-#{arch}",@build_model)
          end
        else
          xcodebuild(defines,options)
        end

        defines
      end

      def is_debug_model
        @build_model == "Debug"
      end

      def target_name
        #区分多平台，如配置了多平台，会带上平台的名字
        # 如libwebp-iOS
        # if @spec.available_platforms.count > 1
        #   "#{@spec.name}-#{Platform.string_name(@spec.consumer(@platform).platform_name)}"
        # else
          @spec.name
        # end
      end

      def xcodebuild(defines = '', args = '', build_dir = 'build',build_model = 'Release')
        #xcodebuild GCC_PREPROCESSOR_DEFINITIONS='$(inherited)'  ARCHS='x86_64 arm64 armv7 armv7s i386' OTHER_CFLAGS='-fembed-bitcode -Qunused-arguments' CONFIGURATION_BUILD_DIR=build clean build -configuration Debug -target IMYTCP -project ./Pods.xcodeproj 2>&1
        # xcodebuild GCC_PREPROCESSOR_DEFINITIONS='$(inherited)'  -sdk iphoneos CONFIGURATION_BUILD_DIR=build-simulator clean build -configuration Release -target IMYFoundation -project ./Pods/Pods.xcodeproj 2>&1
        command = "xcodebuild #{defines} #{args} CONFIGURATION_BUILD_DIR=#{build_dir} clean build -configuration #{build_model} -target #{target_name} -project ./Pods.xcodeproj 2>&1"
        UI.message "command = #{command}"
        output = `#{command}`.lines.to_a

        if $CHILD_STATUS.exitstatus != 0
          raise <<~EOF
            Build command failed: #{command}
            Output:
            #{output.map { |line| "    #{line}" }.join}
          EOF

          Process.exit
        end
      end

      def expand_paths(source_dir, path_specs)
        path_specs.map do |path_spec|
          Dir.glob(File.join(source_dir, path_spec))
        end
      end

      def framework
        @framework ||= begin
          framework = Framework.new(@spec.name, @platform.name.to_s)
          framework.make
          framework
        end
      end
    end
  end
end
