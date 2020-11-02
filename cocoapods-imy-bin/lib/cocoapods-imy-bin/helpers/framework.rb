# copy from https://github.com/CocoaPods/cocoapods-packager

module CBin
  class Framework
    attr_reader :headers_path
    attr_reader :module_map_path
    attr_reader :resources_path
    attr_reader :root_path
    attr_reader :versions_path
    attr_reader :swift_module_path
    attr_reader :fwk_path

    def initialize(name, platform)
      @name = name
      @platform = platform
    end

    def make
      make_root
      make_framework
      make_headers
      make_resources
      make_current_version
    end

    def delete_resources
      Pathname.new(@resources_path).rmtree if File.exist? (@resources_path)
      (Pathname.new(@fwk_path) + Pathname.new('Resources')).delete if File.exist?(Pathname.new(@fwk_path) + Pathname.new('Resources'))
    end

    def remove_current_version
      FileUtils.rm_f(File.join(@fwk_path,@name))
      FileUtils.rm_f(File.join(@fwk_path,"Headers"))
      FileUtils.rm_f(File.join(@fwk_path,"Resources"))

      FileUtils.cp_r("#{@versions_path}/.", @fwk_path)
      # FileUtils.remove_dir(@versions_path)
      FileUtils.remove_dir("#{@fwk_path}/Versions")

      # current_version_path = @versions_path + Pathname.new('../Current')
      # `ln -sf A #{current_version_path}`
      # `ln -sf Versions/Current/Headers #{@fwk_path}/`
      # `ln -sf Versions/Current/Resources #{@fwk_path}/`
      # `ln -sf Versions/Current/#{@name} #{@fwk_path}/`
    end

    private

    def make_current_version
      current_version_path = @versions_path + Pathname.new('../Current')
      `ln -sf A #{current_version_path}`
      `ln -sf Versions/Current/Headers #{@fwk_path}/`
      `ln -sf Versions/Current/Resources #{@fwk_path}/`
      `ln -sf Versions/Current/#{@name} #{@fwk_path}/`
    end



    def make_framework
      @fwk_path = @root_path + Pathname.new(@name + '.framework')
      @fwk_path.mkdir unless @fwk_path.exist?

      @module_map_path = @fwk_path + Pathname.new('Modules')
      @swift_module_path = @module_map_path + Pathname.new(@name + '.swiftmodule')


      @versions_path = @fwk_path + Pathname.new('Versions/A')
    end

    def make_headers
      @headers_path = @versions_path + Pathname.new('Headers')
      @headers_path.mkpath unless @headers_path.exist?
    end

    def make_resources
      @resources_path = @versions_path + Pathname.new('Resources')
      @resources_path.mkpath unless @resources_path.exist?
    end

    def make_root
      @root_path = Pathname.new(@platform)
      @root_path.mkpath unless @root_path.exist?
    end
  end
end
