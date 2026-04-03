require 'cocoapods-imy-bin/config/config'
require 'open3'
require 'time'

module Pod
  class Command
    class Bin < Command
      class Doctor < Bin
        self.summary = '诊断插件环境与配置是否正常.'
        self.description = <<-DESC
          检查插件配置文件、Podfile 声明、私有源仓库、外部工具依赖等，
          输出 pass / warn / fail 诊断结果摘要。支持 --json 输出。
        DESC

        def self.options
          [
            ['--env=ENV', '只检查指定环境 (dev/debug_iphoneos/release_iphoneos)'],
            ['--json', '以 JSON 格式输出诊断结果'],
          ].concat(super)
        end

        def initialize(argv)
          @env = argv.option('env')
          @json_output = argv.flag?('json', false)
          super
        end

        def run
          @results = []

          check_configuration_files
          check_podfile
          check_bin_archive_json
          check_source_repos
          check_external_tools

          if @json_output
            output_json
          else
            output_summary
          end
        end

        private

        def record(category, name, status, message = nil)
          @results << { category: category, name: name, status: status, message: message }
        end

        def check_configuration_files
          envs = @env ? [@env] : %w[dev debug_iphoneos release_iphoneos]
          envs.each do |env|
            begin
              file = CBin.config.config_file_with_configuration_env(env)
            rescue => e
              record('配置', "#{env} 配置文件", :fail, e.message)
              next
            end

            if File.exist?(file)
              begin
                content = YAML.load_file(file)
                if content.is_a?(Hash) && !content.empty?
                  record('配置', "#{env} 配置文件", :pass, file)
                  %w[code_repo_url binary_repo_url binary_download_url].each do |key|
                    if content[key] && !content[key].to_s.strip.empty?
                      record('配置', "#{env}/#{key}", :pass, content[key])
                    else
                      record('配置', "#{env}/#{key}", :warn, '未配置，相关功能将被跳过')
                    end
                  end
                else
                  record('配置', "#{env} 配置文件", :warn, "文件存在但内容为空: #{file}")
                end
              rescue => e
                record('配置', "#{env} 配置文件", :fail, "YAML 解析失败: #{e.message}")
              end
            else
              record('配置', "#{env} 配置文件", :warn, "文件不存在: #{file}")
            end
          end
        end

        def check_podfile
          podfile = Pod::Config.instance.podfile
          unless podfile
            record('Podfile', 'Podfile', :skip, '当前目录下未找到 Podfile')
            return
          end
          record('Podfile', 'Podfile', :pass)

          if podfile.plugins.keys.include?('cocoapods-imy-bin')
            record('Podfile', 'plugin 声明', :pass)
          else
            record('Podfile', 'plugin 声明', :fail, "未声明 plugin 'cocoapods-imy-bin'")
          end

          if podfile.respond_to?(:use_binaries?) && podfile.use_binaries?
            record('Podfile', 'use_binaries!', :pass, '已启用')
          else
            record('Podfile', 'use_binaries!', :warn, '未启用，组件将使用源码依赖')
          end

          env = podfile.respond_to?(:configuration_env) ? podfile.configuration_env : nil
          if env
            record('Podfile', 'configuration_env', :pass, env)
          else
            record('Podfile', 'configuration_env', :warn, '未设置，默认 dev')
          end
        end

        def check_bin_archive_json
          project_root = Pod::Config.instance.project_root
          unless project_root
            record('构建配置', 'BinArchive.json', :skip, '无项目根目录')
            return
          end

          path = File.join(project_root.to_s, 'BinArchive.json')
          unless File.exist?(path)
            record('构建配置', 'BinArchive.json', :skip, '文件不存在，使用默认配置')
            return
          end

          begin
            config = JSON.parse(File.read(path))
            record('构建配置', 'BinArchive.json', :pass, path)
            %w[archive-white-pod-list ignore-git-list].each do |key|
              if config[key]
                record('构建配置', key, :pass, "#{config[key].length} 项")
              else
                record('构建配置', key, :skip, '未配置')
              end
            end
          rescue JSON::ParserError => e
            record('构建配置', 'BinArchive.json', :fail, "JSON 解析失败: #{e.message}")
          end
        end

        def check_source_repos
          sources_manager = Pod::Config.instance.sources_manager

          code_url = begin; CBin.config.code_repo_url; rescue; nil; end
          if code_url && !code_url.to_s.strip.empty?
            begin
              source = sources_manager.source_with_name_or_url(code_url)
              record('私有源', '源码私有源', :pass, "#{code_url} → #{source.name}")
            rescue => e
              record('私有源', '源码私有源', :fail, "无法解析 #{code_url}: #{e.message}")
            end
          else
            record('私有源', '源码私有源', :warn, '未配置 code_repo_url')
          end

          bin_url = begin; CBin.config.binary_repo_url; rescue; nil; end
          if bin_url && !bin_url.to_s.strip.empty?
            begin
              source = sources_manager.source_with_name_or_url(bin_url)
              record('私有源', '二进制私有源', :pass, "#{bin_url} → #{source.name}")
            rescue => e
              record('私有源', '二进制私有源', :fail, "无法解析 #{bin_url}: #{e.message}")
            end
          else
            record('私有源', '二进制私有源', :warn, '未配置 binary_repo_url')
          end
        end

        def check_external_tools
          check_tool('git', %w[git --version])
          check_tool('pod', %w[pod --version])
          check_tool('xcodebuild', %w[xcodebuild -version])

          podfile = Pod::Config.instance.podfile
          if podfile && podfile.respond_to?(:use_hmap?) && podfile.use_hmap?
            check_tool('hmap', %w[hmap --version])
          else
            record('工具', 'hmap', :skip, '未启用 use_hmap!')
          end
        end

        def check_tool(name, cmd)
          stdout, stderr, status = Open3.capture3(*cmd)
          if status.success?
            version_line = (stdout.lines.first || stderr.lines.first || '').strip
            record('工具', name, :pass, version_line)
          else
            record('工具', name, :fail, "执行失败: #{stderr.strip}")
          end
        rescue Errno::ENOENT
          record('工具', name, :fail, '未安装或不在 PATH 中')
        end

        def output_summary
          UI.puts "\n#{'=' * 50}"
          UI.puts "  cocoapods-imy-bin Doctor (#{CBin::VERSION})"
          UI.puts "#{'=' * 50}\n\n"

          current_category = nil
          @results.each do |r|
            if r[:category] != current_category
              current_category = r[:category]
              UI.puts "【#{current_category}】"
            end
            icon = { pass: '✅', warn: '⚠️ ', fail: '❌', skip: '⏭️ ' }[r[:status]]
            line = "  #{icon} #{r[:name]}"
            line += " — #{r[:message]}" if r[:message]
            UI.puts line
          end

          counts = @results.group_by { |r| r[:status] }.transform_values(&:count)
          UI.puts "\n#{'—' * 50}"
          parts = ["#{counts[:pass] || 0} pass"]
          parts << "#{counts[:warn] || 0} warn" if (counts[:warn] || 0) > 0
          parts << "#{counts[:fail] || 0} fail" if (counts[:fail] || 0) > 0
          parts << "#{counts[:skip] || 0} skip" if (counts[:skip] || 0) > 0
          UI.puts "  摘要: #{parts.join(' / ')}"
          UI.puts ''
        end

        def output_json
          require 'json'
          report = {
            version: CBin::VERSION,
            timestamp: Time.now.iso8601,
            results: @results.map do |r|
              { 'category' => r[:category], 'name' => r[:name], 'status' => r[:status].to_s, 'message' => r[:message] }
            end,
            summary: @results.group_by { |r| r[:status] }.transform_values(&:count).transform_keys(&:to_s)
          }
          UI.puts JSON.pretty_generate(report)
        end
      end
    end
  end
end
