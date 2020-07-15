
require 'cocoapods'
require 'cocoapods-imy-bin/native/podfile_env'
require 'cocoapods-imy-bin/native/podfile'

module Pod
  class Command
    class Bin < Command
      class Update < Bin
        include Pod
        include Pod::Podfile::DSL

        self.summary = 'pod update 拦截器，会加载本地Podfile_local文件，DSL加载到原始Podfile文件中。'

        self.description = <<-DESC
          pod update 拦截器，会加载本地Podfile_local文件
          会通过DSL加载到原始Podfile文件中
          支持 pod 'xxx' 各种写法
          支持 post_install/pre_install钩子，采用覆盖做法
        DESC
        def self.options
          [
            ["--sources=#{Pod::TrunkSource::TRUNK_REPO_URL}", 'The sources from which to update dependent pods. ' \
              'Multiple sources must be comma-delimited'],
            ['--exclude-pods=podName', 'Pods to exclude during update. Multiple pods must be comma-delimited'],
            ['--clean-install', 'Ignore the contents of the project cache and force a full pod installation. This only ' \
              'applies to projects that have enabled incremental installation'],
            ['--project-directory=/project/dir/', 'The path to the root of the project directory'],
            ['--no-repo-update', 'Skip running `pod repo update` before install']
          ].concat(super)
        end

        def initialize(argv)
          @update = argv.flag?('update')
          super
          @additional_args = argv.remainder!
        end

        def run
          Update.load_local_podfile

          argvs = [
            *@additional_args
          ]

          gen = Pod::Command::Update.new(CLAide::ARGV.new(argvs))
          gen.validate!
          gen.run
        end

        def self.load_local_podfile
          # 同步 Podfile_local 文件
          project_root = Pod::Config.instance.project_root
          path = File.join(project_root.to_s, 'Podfile_local')
          unless File.exist?(path)
            path = File.join(project_root.to_s, 'Podfile_local')
          end

          if File.exist?(path)
            contents = File.open(path, 'r:utf-8', &:read)

            podfile = Pod::Config.instance.podfile
            local_podfile = Podfile.from_file(path)

            if local_podfile
              local_pre_install_callback = nil
              local_post_install_callback = nil
              local_podfile.instance_eval do
                local_pre_install_callback = @pre_install_callback
                local_post_install_callback = @post_install_callback
              end
            end

            podfile.instance_eval do
              begin

                # podfile HASH_KEYS才有plugins字段，否则会被限制
                if local_podfile.plugins.any?
                  hash_plugins = podfile.plugins || {}
                  hash_plugins = hash_plugins.merge(local_podfile.plugins)
                  set_hash_value(%w[plugins].first, hash_plugins)

                  # 加入源码白名单，避免本地库被二进制了
                  podfile.set_use_source_pods(local_podfile.use_source_pods) if local_podfile.use_source_pods
                  podfile.use_binaries!(local_podfile.use_binaries?)
                end

                # 在target把local-target中到dependencies值删除了，再设置
                # 把本地和原始到dependencies 合并，设置dependencies
                local_podfile&.target_definition_list&.each do |local_target|
                  next if local_target.name == 'Pods'

                  target_definition_list.each do |target|

                    unless target.name == local_target.name &&
                        (local_target.to_hash['dependencies'] &&local_target.to_hash['dependencies'].any?)
                      next
                    end



                    target.instance_exec do
                      # 在target把local-target中到dependencies值删除了，再设置

                      local_dependencies = local_target.to_hash['dependencies']
                      target_dependencies = target.to_hash['dependencies']

                      local_dependencies.each do |local_dependency|
                        unless local_dependency.is_a?(Hash) && local_dependency.keys.first
                          next
                        end

                        target_dependencies.each do |target_dependency|
                          next unless target_dependency.is_a?(Hash) &&
                                      target_dependency.keys.first &&
                                      target_dependency.keys.first == local_dependency.keys.first

                          target_dependencies.delete target_dependency
                          break
                        end
                      end
                      # 把本地和原始到dependencies 合并，设置dependencies
                      local_dependencies.each do |d|
                        UI.message "Development Pod #{d.to_yaml}"
                        if podfile.plugins.keys.include?('cocoapods-imy-bin')
                          podfile.set_use_source_pods(d.keys.first) if (d.is_a?(Hash) && d.keys.first)
                        end
                      end
                      new_dependencies = target_dependencies + local_dependencies
                      set_hash_value(%w[dependencies].first, new_dependencies)

                    end
                  end

                end

                if local_pre_install_callback
                  @pre_install_callback = local_pre_install_callback
                end
                if local_post_install_callback
                  @post_install_callback = local_post_install_callback
                end
              rescue Exception => e
                message = "Invalid `#{path}` file: #{e.message}"
                raise Pod::DSLError.new(message, path, e, contents)
              end
            end

          end
        end
      end
    end
  end
end
