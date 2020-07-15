require 'cocoapods-imy-bin/native/sources_manager'
require 'cocoapods-imy-bin/command/bin/repo/update'
require 'cocoapods/user_interface'

Pod::HooksManager.register('cocoapods-imy-bin', :pre_install) do |_context, _|
  require 'cocoapods-imy-bin/native'

  # pod bin repo update 更新二进制私有源
  Pod::Command::Bin::Repo::Update.new(CLAide::ARGV.new([])).run

  # 有插件/本地库 且是dev环境下，默认进入源码白名单  过滤 archive命令
  if _context.podfile.plugins.keys.include?('cocoapods-imy-bin') && _context.podfile.configuration_env == 'dev'
    dependencies = _context.podfile.dependencies
    dependencies.each do |d|
      next unless d.respond_to?(:external_source) &&
                  d.external_source.is_a?(Hash) &&
                  !d.external_source[:path].nil? &&
                  $ARGV[1] != 'archive'
      _context.podfile.set_use_source_pods d.name
    end
  end

  # 同步 BinPodfile 文件
  project_root = Pod::Config.instance.project_root
  path = File.join(project_root.to_s, 'BinPodfile')

  next unless File.exist?(path)

  contents = File.open(path, 'r:utf-8', &:read)
  podfile = Pod::Config.instance.podfile
  podfile.instance_eval do
    begin
      eval(contents, nil, path)
    rescue Exception => e
      message = "Invalid `#{path}` file: #{e.message}"
      raise Pod::DSLError.new(message, path, e, contents)
    end
  end
end

Pod::HooksManager.register('cocoapods-imy-bin', :source_provider) do |context, _|
  sources_manager = Pod::Config.instance.sources_manager
  podfile = Pod::Config.instance.podfile

  if podfile
    # 添加源码私有源 && 二进制私有源
    added_sources = [sources_manager.code_source]
    if podfile.use_binaries? || podfile.use_binaries_selector
      added_sources << sources_manager.binary_source
      added_sources.reverse!
   end
    added_sources.each { |source| context.add_source(source) }
  end
end
