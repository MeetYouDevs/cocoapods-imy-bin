

require 'cocoapods-imy-bin/native/specification'

module Pod
  class Sandbox
    class PodspecFinder
      def podspecs
        return @specs_by_name if @specs_by_name

        @specs_by_name = {}
        spec_files = Pathname.glob(root + '{,*}.podspec{,.json}')
        # pod 指向分支时，如果目标组件有 subspec ，并且有 template spec ，request 之后使用的 spec 不应该为 template spec
        # 这里做下过滤
        spec_files = spec_files.reject { |p| Specification::DEFAULT_TEMPLATE_EXTNAME.find { |e| p.to_s.end_with?(e) } }
        spec_files.sort_by { |p| -p.to_path.split(File::SEPARATOR).size }.each do |file|
          spec = Specification.from_file(file)
          spec.validate_cocoapods_version
          @specs_by_name[spec.name] = spec
        end
        @specs_by_name
      end
    end
  end
end
