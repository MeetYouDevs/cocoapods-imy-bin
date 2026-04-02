

require 'cocoapods-imy-bin/native/installation_options'

module Pod
  class Installer
    # Cocoapods新版本（1.15.2）将 PodSourceInstaller 的
    # verify_source_is_secure 等方法迁移到 PodSourceDownloader
    # 所以这里需要修改一下
    class PodSourceDownloader
      attr_accessor :installation_options

      # alias old_verify_source_is_secure verify_source_is_secure
      # def verify_source_is_secure(root_spec)
      #   # http source 默认不警告
      #   if installation_options.warn_for_unsecure_source?
      #     old_verify_source_is_secure(root_spec)
      #   end
      # end
    end
  end

  class Installer
    # 新增  PodSourceInstaller 的 installation_options 扩展方法
    class PodSourceInstaller
      attr_accessor :installation_options
    end
  end
end
