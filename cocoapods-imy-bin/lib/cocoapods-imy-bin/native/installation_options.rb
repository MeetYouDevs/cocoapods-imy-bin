
require 'cocoapods'

module Pod
  class Installer
    class InstallationOptions
      def self.env_option(key, default = true)
        option key, ENV[key.to_s].nil? ? default : ENV[key.to_s] == 'true'
      end

      # 不同 source 存在相同 spec 名时，默认不警告
      defaults.delete('warn_for_multiple_pod_sources')
      env_option :warn_for_multiple_pod_sources, false

      # 是否警告不安全 source （如 http ）
      env_option :warn_for_unsecure_source, false

      # 是否多线程执行 install_pod_sources
      env_option :install_with_multi_threads, true

      # 是否多进程执行 update_repositories
      env_option :update_source_with_multi_processes, true
    end
  end
end
