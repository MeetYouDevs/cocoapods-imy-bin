

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

      def inspect_targets_to_integrate
        @ignored_missing_target_definitions = []
        inspection_result = {}
        UI.section 'Inspecting targets to integrate' do
          inspectors = @podfile_dependency_cache.target_definition_list.map do |target_definition|
            next if target_definition.abstract?
            TargetInspector.new(target_definition, config.installation_root)
          end.compact
          inspectors.group_by(&:compute_project_path).each do |project_path, target_inspectors|
            project = Xcodeproj::Project.open(project_path)
            target_inspectors.each do |inspector|
              target_definition = inspector.target_definition
              begin
                results = inspector.compute_results(project)
              rescue IgnoreMissingTargetDefinition => e
                @ignored_missing_target_definitions << e.target_definition
                UI.warn "#{e.message} Skipping target `#{target_definition.name}` because `--imt` is enabled."
                next
              end

              inspection_result[target_definition] = results
              UI.message('Using `ARCHS` setting to build architectures of ' \
                "target `#{target_definition.label}`: (`#{results.archs.join('`, `')}`)")
            end
          end
        end
        inspection_result
      end

      alias old_resolve_dependencies resolve_dependencies
      def resolve_dependencies(locked_dependencies)
        resolver_specs_by_target = old_resolve_dependencies(locked_dependencies)
        reject_ignored_missing_target_definitions(resolver_specs_by_target)
      end

      private

      def reject_ignored_missing_target_definitions(resolver_specs_by_target)
        ignored_target_definitions = Array(@ignored_missing_target_definitions)
        return resolver_specs_by_target if ignored_target_definitions.empty?

        resolver_specs_by_target.reject do |target_definition, _|
          ignored_target_definitions.include?(target_definition)
        end
      end


    end
  end
end
