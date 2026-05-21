
require 'cocoapods'
require 'open3'
require 'cocoapods-imy-bin/config/config'
require 'cocoapods-imy-bin/native/podfile_env'
require 'cocoapods-imy-bin/native/podfile'

module Pod
  class Command
    class Bin < Command
      class Update < Bin
        include Pod
        include Pod::Podfile::DSL
        include Pod::Podfile::ENVExecutor

        self.summary = 'pod update 拦截器，会加载本地Podfile_local文件，DSL加载到原始Podfile文件中。'

        self.description = <<-DESC
          pod update 拦截器，会加载本地Podfile_local文件
          会通过DSL加载到原始Podfile文件中
          支持 pod 'xxx' 各种写法
          支持 post_install/pre_install钩子，采用覆盖做法
        DESC
        def self.options
          [
            ["--sources=#{Pod::TrunkSource::TRUNK_REPO_URL}", 'The sources from which to update dependent pods. ' \
              'Multiple sources must be comma-delimited'],
            ['--exclude-pods=podName', 'Pods to exclude during update. Multiple pods must be comma-delimited'],
            ['--imt', 'Ignore missing user target name mismatches and fall back to the first native target in the Xcode project'],
            ['--clean-install', 'Ignore the contents of the project cache and force a full pod installation. This only ' \
              'applies to projects that have enabled incremental installation'],
            ['--project-directory=/project/dir/', 'The path to the root of the project directory'],
            ['--no-repo-update', 'Skip running `pod repo update` before install'],
            ['--l', '更新前先 git pull Podfile_local 所在仓库']
          ].concat(super)
        end

        def initialize(argv)
          @update = argv.flag?('update')
          @update_local = argv.flag?('l', CBin.config.update_local?)
          @imt = argv.flag?('imt')
          super
          @additional_args = argv.remainder!
        end

        def run
          update_podfile_local_repo_if_needed
          Update.load_local_podfile

          argvs = [
            *@additional_args
          ]

          gen = Pod::Command::Update.new(CLAide::ARGV.new(argvs))
          execute_with_ignore_missing_targets(@imt) do
            gen.validate!
            gen.run
          end
        end

        def self.detect_podfile_local_repo_dir
          project_root = Pod::Config.instance.project_root
          podfile_local = File.join(project_root.to_s, 'Podfile_local')
          return nil unless File.exist?(podfile_local)

          real_dir = File.dirname(File.realpath(podfile_local))
          stdout, _, status = Open3.capture3('git', '-C', real_dir, 'rev-parse', '--show-toplevel')
          status.success? ? stdout.strip : nil
        end

        def self.update_podfile_local_repo!
          repo_dir = detect_podfile_local_repo_dir
          if repo_dir.nil? || repo_dir.empty?
            raise Pod::Informative, '找不到 Podfile_local 或其不在 Git 仓库中'
          end

          UI.section("\nUpdating Podfile_local Repository (#{repo_dir})\n".yellow) do
            stdout, stderr, status = Open3.capture3('git', '-C', repo_dir, 'pull', '--ff-only')
            UI.puts stdout unless stdout.to_s.strip.empty?

            next if status.success?

            error_output = stderr.to_s.strip
            error_output = stdout.to_s.strip if error_output.empty?
            raise Pod::Informative, "更新 Podfile_local git 仓库失败: #{error_output}"
          end

          update_development_pods!
        rescue Errno::ENOENT
          raise Pod::Informative, '未找到 git 命令，请确认 git 已安装并在 PATH 中'
        end

        def self.collect_development_pod_paths
          project_root = Pod::Config.instance.project_root
          path = File.join(project_root.to_s, 'Podfile_local')
          return [] unless File.exist?(path)

          local_podfile = Podfile.from_file(path)
          return [] unless local_podfile

          paths = []
          local_podfile.target_definition_list.each do |target_def|
            deps = target_def.to_hash['dependencies']
            next unless deps.is_a?(Array)

            deps.each do |dep|
              next unless dep.is_a?(Hash)

              dep.each do |name, options|
                next unless options.is_a?(Array)

                options.each do |opt|
                  next unless opt.is_a?(Hash) && opt[:path]

                  full_path = File.expand_path(opt[:path], project_root)
                  paths << { name: name, path: full_path } if Dir.exist?(full_path)
                end
              end
            end
          end
          paths.uniq { |p| p[:path] }
        end

        def self.update_development_pods!
          pods = collect_development_pod_paths
          return if pods.empty?

          UI.section("\nUpdating Development Pods\n".yellow) do
            pods.each do |pod|
              # 跳过不是 git 仓库的目录
              _, _, rev_status = Open3.capture3('git', '-C', pod[:path], 'rev-parse', '--show-toplevel')
              unless rev_status.success?
                UI.puts "  ⏭  #{pod[:name]} (#{pod[:path]}) 不是 Git 仓库，跳过"
                next
              end

              stdout, stderr, status = Open3.capture3('git', '-C', pod[:path], 'pull')
              if status.success?
                msg = stdout.to_s.strip
                msg = 'Already up to date.' if msg.empty?
                UI.puts "  ✅ #{pod[:name]} — #{msg}"
              else
                error = stderr.to_s.strip
                error = stdout.to_s.strip if error.empty?
                UI.warn "  ❌ #{pod[:name]} git pull 失败 (#{pod[:path]}):\n    #{error}".red
              end
            end
          end
        end

        def self.load_local_podfile
          # 同步 Podfile_local 文件
          project_root = Pod::Config.instance.project_root
          path = File.join(project_root.to_s, 'Podfile_local')

          if File.exist?(path)
            contents = File.open(path, 'r:utf-8', &:read)

            podfile = Pod::Config.instance.podfile
            local_podfile = Podfile.from_file(path)

            if local_podfile
              local_pre_install_callback = nil
              local_post_install_callback = nil
              local_podfile.instance_eval do
                local_pre_install_callback = @pre_install_callback
                local_post_install_callback = @post_install_callback
              end
            end
            local_podfile_internal_hash = nil
            local_podfile.instance_eval do
              begin
                local_podfile_internal_hash = internal_hash
              end
            end


            podfile.instance_eval do
              begin
                internal_hash.merge!(local_podfile_internal_hash)

                # podfile HASH_KEYS才有plugins字段，否则会被限制
                if local_podfile.plugins.any?
                  hash_plugins = podfile.plugins || {}
                  hash_plugins = hash_plugins.merge(local_podfile.plugins)
                  set_hash_value(%w[plugins].first, hash_plugins)

                  # 加入源码白名单，避免本地库被二进制了
                  podfile.set_use_source_pods(local_podfile.use_source_pods) if local_podfile.use_source_pods
                  podfile.use_binaries!(local_podfile.use_binaries?)
                end

                # 在target把local-target中到dependencies值删除了，再设置
                # 把本地和原始到dependencies 合并，设置dependencies
                local_podfile&.target_definition_list&.each do |local_target|
                  next if local_target.name == 'Pods'

                  target_definition_list.each do |target|

                    unless target.name == local_target.name &&
                        (local_target.to_hash['dependencies'] &&local_target.to_hash['dependencies'].any?)
                      next
                    end



                    target.instance_exec do
                      # 在target把local-target中到dependencies值删除了，再设置

                      local_dependencies = local_target.to_hash['dependencies']
                      target_dependencies = target.to_hash['dependencies']

                      local_dependencies.each do |local_dependency|
                        unless local_dependency.is_a?(Hash) && local_dependency.keys.first
                          next
                        end

                        target_dependencies.each do |target_dependency|
                          dp_hash_equal = target_dependency.is_a?(Hash) &&
                            target_dependency.keys.first &&
                            target_dependency.keys.first == local_dependency.keys.first
                          dp_str_equal = target_dependency.is_a?(String) &&
                            target_dependency == local_dependency.keys.first
                          next unless dp_hash_equal || dp_str_equal

                          target_dependencies.delete target_dependency
                          break
                        end
                      end
                      # 把本地和原始到dependencies 合并，设置dependencies
                      local_dependencies.each do |d|
                        UI.message "Development Pod #{d.to_yaml}"
                        if podfile.plugins.keys.include?('cocoapods-imy-bin')
                          podfile.set_use_source_pods(d.keys.first) if (d.is_a?(Hash) && d.keys.first)
                        end
                      end
                      new_dependencies = target_dependencies + local_dependencies
                      set_hash_value(%w[dependencies].first, new_dependencies)

                    end
                  end

                end

                if local_pre_install_callback
                  @pre_install_callback = local_pre_install_callback
                end
                if local_post_install_callback
                  @post_install_callback = local_post_install_callback
                end
              rescue Exception => e
                message = "Invalid `#{path}` file: #{e.message}"
                raise Pod::DSLError.new(message, path, e, contents)
              end
            end

          end
        end

        private

        def update_podfile_local_repo_if_needed
          return unless @update_local

          self.class.update_podfile_local_repo!
        end
      end
    end
  end
end
