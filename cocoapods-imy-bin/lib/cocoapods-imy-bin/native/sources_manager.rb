

require 'cocoapods'
require 'cocoapods-imy-bin/config/config'

module Pod
  class Source
    class Manager
      # 源码 source
      def code_source
        source_url = CBin.config.code_repo_url
        return nil if source_url.nil? || source_url.to_s.strip.empty?

        source_with_name_or_url(source_url)
      end

      # 二进制 source
      def binary_source
        source_url = CBin.config.binary_repo_url
        return nil if source_url.nil? || source_url.to_s.strip.empty?

        source_with_name_or_url(source_url)
      end
    end
  end
end
