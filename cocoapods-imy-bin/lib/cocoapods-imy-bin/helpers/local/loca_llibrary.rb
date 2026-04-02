

# copy from https://github.com/CocoaPods/cocoapods-packager
require 'cocoapods-imy-bin/config/config_builder'

module CBin
  class LocalLibrary
    attr_reader :headers_path
    attr_reader :resources_path
    attr_reader :root_path
    attr_reader :versions_path
    attr_reader :name_path

    def initialize(name, platform, version)
      @name = name
      @platform = platform
      @version = version
    end

    def make
      make_root
      make_library
      make_headers
      make_resources
    end

    def delete_resources
      Pathname.new(@resources_path).rmtree
      (Pathname.new(@fwk_path) + Pathname.new('Resources')).delete
    end

    private

    def make_library
      @name_path = CBin::Config::Builder.instance.library_name_version(@name, @version)
      @fwk_path = @root_path + Pathname.new(@name_path)
      @fwk_path.mkdir unless @fwk_path.exist?

      @versions_path = @fwk_path
    end

    def make_headers
      @headers_path = @versions_path + Pathname.new('Headers')
      # @headers_path.mkpath unless @headers_path.exist?
    end

    def make_resources
      @resources_path = @versions_path + Pathname.new('Resources')
      # @resources_path.mkpath unless @resources_path.exist?
    end

    def make_root
      @root_path = Pathname.new(@platform)
      @root_path.mkpath unless @root_path.exist?
    end
  end
end
