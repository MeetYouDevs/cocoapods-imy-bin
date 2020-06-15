

module Pod
  class Installer
    class Analyzer
      class SandboxAnalyzer
        # def pod_changed?(pod)
        #     spec = root_spec(pod)
        # 有 subspec 的情况下，root spec 对应的 used_files 可能始终为空
        # 要添加为空 && 没有 subspec 的情况
        #      file_accessors = spec.available_platforms.map { |platform| Sandbox::FileAccessor.new(sandbox.pod_dir(pod), spec.consumer(platform)) }
        #      files = [
        #       file_accessors.map(&:vendored_frameworks),
        #       file_accessors.map(&:vendored_libraries),
        #       file_accessors.map(&:resource_bundle_files),
        #       file_accessors.map(&:prefix_header),
        #       file_accessors.map(&:resources),
        #       file_accessors.map(&:source_files),
        #       file_accessors.map(&:module_map),
        #     ]
        # used_files = files.flatten.compact.map(&:to_s).uniq
        # p pod if used_files.empty?

        # return true if spec.version != sandbox_version(pod)
        # return true if spec.checksum != sandbox_checksum(pod)
        # return true if resolved_spec_names(pod) != sandbox_spec_names(pod)
        # return true if sandbox.predownloaded?(pod)
        # return true if folder_empty?(pod)
        # false
        # end
      end
    end
  end
end
