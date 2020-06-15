

require 'cocoapods-imy-bin/native/specification'

module Pod
  module ExternalSources
    # Provides support for fetching a specification file from a path local to
    # the machine running the installation.
    #
    class PathSource < AbstractExternalSource
      def normalized_podspec_path(declared_path)
        extension = File.extname(declared_path)

        if extension == '.podspec' || extension == '.json'
          path_with_ext = declared_path
        else
          # 默认先从 binary podspec 找起，因为 binary podspec 的 subspec 可能比 code podspec 多
          # 这里可能出现 code subspec 和 binary subspec 对应不上的情况，导致 lint 失败
          # 所以不要在 code podspec 同一目录下保留 binary podspec
          path_with_ext = Specification::VALID_EXTNAME
                          .map { |extname| "#{declared_path}/#{name}#{extname}" }
                          .find { |file| File.exist?(file) } || "#{declared_path}/#{name}.podspec"
        end

        UI.message "获取的 podspec 路径为 `#{path_with_ext}`"

        podfile_dir = File.dirname(podfile_path || '')

        File.expand_path(path_with_ext, podfile_dir)
      end
    end
  end
end
