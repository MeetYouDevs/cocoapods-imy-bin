

require 'cocoapods-imy-bin/native/sources_manager.rb'

module CBin
  module SourcesHelper
    def sources_manager
      Pod::Config.instance.sources_manager
    end

    def binary_source
      sources_manager.binary_source
    end

    def code_source
      sources_manager.code_source
    end

    # 优先采用对应依赖的 source
    # cocoapods 内部会先匹配前面符合的 specification
    # 只允许二进制的 specification subspec 比源码的 specification subspec 多
    #
    def valid_sources(code_dependencies = false)
      sources = [code_source]
      unless code_dependencies
        sources << binary_source
        sources.reverse!
      end
      sources
    end

    def sources_option(code_dependencies, additional_sources)
      (valid_sources(code_dependencies).map(&:url) + Array(additional_sources)).join(',')
    end
  end
end
