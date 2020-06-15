

require 'parallel'
require 'cocoapods'

module Pod
  class Installer
    class Analyzer
      # > 1.6.0
      # all_specs[dep.name] 为 nil 会崩溃
      # 主要原因是 all_specs 分析错误
      # 查看 source 是否正确
      #
      # def dependencies_for_specs(specs, platform, all_specs)
      #   return [] if specs.empty? || all_specs.empty?

      #   dependent_specs = Set.new

      #   specs.each do |s|
      #     s.dependencies(platform).each do |dep|
      #       all_specs[dep.name].each do |spec|
      #         dependent_specs << spec
      #       end
      #     end
      #   end

      #   dependent_specs - specs
      # end

      # > 1.5.3 版本
      # rewrite update_repositories
      #
      alias old_update_repositories update_repositories
      def update_repositories
        if installation_options.update_source_with_multi_processes
          # 并发更新私有源
          # 这里多线程会导致 pod update 额外输出 --verbose 的内容
          # 不知道为什么？
          Parallel.each(sources.uniq(&:url), in_processes: 4) do |source|
            if source.git?
              config.sources_manager.update(source.name, true)
            else
              UI.message "Skipping `#{source.name}` update because the repository is not a git source repository."
            end
          end
          @specs_updated = true
        else
          old_update_repositories
        end
      end
    end
  end
end
