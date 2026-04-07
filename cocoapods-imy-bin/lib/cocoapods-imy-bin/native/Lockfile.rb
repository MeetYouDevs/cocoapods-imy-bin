require 'parallel'
require 'cocoapods'
require 'cocoapods-core/lockfile'
require 'fileutils'

module Pod
  class Lockfile

    # 处理 下载文件为空的情况
    #交换 Lockfile 下的 detect_changes_with_podfile，拿到 result
    #并且取出 result下的 unchanged下的列表，判断各个spec是否存在超过一个文件，
    #如果不存在就删除该文件夹，移除result[:unchanged]中的值，并且加入result[:added],
      alias old_detect_changes_with_podfile detect_changes_with_podfile
      def detect_changes_with_podfile(podfile)
        result = old_detect_changes_with_podfile(podfile)
        result[:unchanged].each do |name|
          spec_path = File.join(Pod::Config.instance.sandbox_root,name)

          if File.directory?(spec_path)
            # 文件小于1个，认定是空的，需要重新下载podspec
            file_count = Dir.glob(File.join(spec_path, '**', '*')).select { |file| File.file?(file) }.count
            #用于判断是否文件，太少就认定是失败了
            if file_count < 1
              FileUtils.rm_rf(spec_path)
              result[:added] << name
              UI.warn "====== #{name} ==== #{spec_path} 为空，请注意 ======== "
            end
          end

        end

        result
      end

    end
end
