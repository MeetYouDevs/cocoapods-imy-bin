require 'cocoapods-imy-bin/config/config_hot_key_asker'
require 'tmpdir'

module Pod
  class Command
    class Bin < Command
      class Clean < Bin
        self.summary = '清除缓存'
        self.description = <<-DESC
            清除缓存
            1、清除私有源spec仓库缓存
            2、清除二进制仓库编译产物
            3、清除增量构建 manifest 与 resolver 报告
        DESC

        def self.options
          [
              ['--env=configuration_env', '清除哪个环境，在.cocoapods下的 bin_dev.yml的配置项，dev'],
              ['--list=[module,module,...]', '清除某个仓库下的模块 TODO'],
              ['--all', '清除所有 TODO'],
              ['--incremental', '仅清除增量构建 manifest 和 resolver 报告'],
          ].concat(Pod::Command::Gen.options).concat(super).uniq
        end


        def initialize(argv)
          @env =  argv.option('env') || nil
          @list = argv.flag?('list', [] )
          @all_clean = argv.flag?('all', false )
          @incremental_clean = argv.flag?('incremental', false)

          @config = Pod::Config.instance

          super
        end


        def run
          if @incremental_clean
            clean_incremental_data
            return
          end

          #清除所有仓库缓存
          if @all_clean
            clean_incremental_data
          elsif @env  #是否存在spec仓库
            #获取对应环境地址
             CBin.config.set_configuration_env(@env)
             @config = CBin.config
            unless @config
              raise "请检查 env = #{@env} 私有源仓库是否设置正常"
            end

            # #1、清除git
            reset_binary_repo
            # #2、更新本地仓库源
            update_cocoapods_repo
            #3、删除二进制私有源存储二进制文件
            update_cocoapods_repo

             delete_build_binary
            #4、清除cocoapods pods cache
            update_cocopods_pods_cache

            # @config.clean_binary_url
          else #不存在spec仓库、就抛异常
            raise "未设置 spec 私有源仓库"
          end

        end

        #一、清除git上的仓库
        # 1、拿到仓库地址 CBin.config.binary_repo_url
        # 2、clone仓库
        # 3、删除仓库下所有可见目录，除了.git
        # 4、提交删除记录
        def reset_binary_repo
          work_dir = Dir.tmpdir + '/cocoapods-imy-bin-' + Array.new(8) { rand(36).to_s(36) }.join
          UI.puts "临时目录 work_dir = #{work_dir}"
          Pathname.new(work_dir).mkdir

          `git clone #{@config.binary_repo_url} #{work_dir}`

          deleteDirectory(work_dir)
          UI.puts "binary_repo_url = #{@config.binary_repo_url}"

          #在当前目录下 做git操作，才能提交成功
          Dir.chdir(work_dir) do
            UI.puts "当前目录 = #{Dir.pwd}"
            `git add .`
            `git commit -m "cocopods-imy-bin auto del"`
            `/usr/bin/git push`
          end

        end

        #二、更新本地仓库源，
        # pod repo update xxx
        def update_cocoapods_repo
          `pod repo update`
          UI.puts "完成pod repo update"
        end

        #三、删除二进制私有源存储二进制文件，
        def delete_build_binary
          `curl #{@config.delete_binary_url}`
          UI.puts "完成删除服务器二进制包"
        end

        #四、清除cocoapods pods cache
        def update_cocopods_pods_cache
          `pod cache clean --all --verbose`
          UI.puts "完成清除本地pod cache"
        end


        #遍历文件夹
        def deleteDirectory(dirPath)
          if File.directory?(dirPath)
            puts "是文件夹";
            Dir.foreach(dirPath) do |subFile|
              if subFile != '.' and subFile != '..' and subFile != ".git"
                FileUtils.remove_entry(File.join(dirPath, subFile))
              end
            end
          end
        end

        def clean_incremental_data
          cleaned = []

          # 清除增量 manifest
          begin
            require 'cocoapods-imy-bin/config/config_builder'
            root_dir = CBin::Config::Builder.instance.root_dir.to_s
            manifest_path = File.join(root_dir, '.bin-manifest.json')
            if File.exist?(manifest_path)
              FileUtils.rm_f(manifest_path)
              cleaned << manifest_path
            end
          rescue => e
            UI.warn "清除 manifest 失败: #{e.message}"
          end

          # 清除 resolver 报告
          sandbox = Pod::Config.instance.sandbox_root rescue nil
          if sandbox
            report_path = File.join(sandbox.to_s, 'bin-report.json')
            if File.exist?(report_path)
              FileUtils.rm_f(report_path)
              cleaned << report_path
            end
          end

          if cleaned.any?
            UI.puts "已清除: #{cleaned.join(', ')}"
          else
            UI.puts "无需清除，未找到 manifest 或 report 文件"
          end
        end


      end
    end
  end
end
