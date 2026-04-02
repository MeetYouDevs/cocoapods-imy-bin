require 'cocoapods-imy-bin/native/sources_manager'
require 'cocoapods-imy-bin/command/bin/repo/update'
require 'cocoapods/user_interface'
require 'xcodeproj/config/other_linker_flags_parser'
require 'xcodeproj/config'

module Xcodeproj
  class Config
    def remove_attr_with_key(key)
      unless key == nil
        @attributes.delete(key)
      end
    end
    def remove_header_search_path
      remove_attr_with_key('HEADER_SEARCH_PATHS')
      flags = @attributes['OTHER_CFLAGS']
      if flags
        new_flags = ''
        skip = false
        flags.split(' ').each do |substr|
          if skip
            skip = false
            next
          end
          if substr == '-isystem'
            skip = true
            next
          end
          if new_flags.length > 0
            new_flags += ' '
          end
          new_flags += substr
        end
        if new_flags.length > 0
          @attributes['OTHER_CFLAGS'] = new_flags
        else
          remove_attr_with_key('OTHER_CFLAGS')
        end
      end
    end
  end
end

module Pod
  class Installer
    class PostInstallHooksContext
      attr_accessor :aggregate_targets
      def self.generate(sandbox, pods_project, pod_target_subprojects, aggregate_targets)
        context = super
        UI.info "[#] generate method of post install hook context override"
        context.aggregate_targets = aggregate_targets
        context
      end
    end
  end
  module ProjectHeaderMap
    HooksManager.register('cocoapods-imy-bin', :post_install) do |post_context|

      podfile = Pod::Config.instance.podfile


      if podfile && podfile.use_hmap?
        UI.info "[#] use hmap for this project"
        post_context.aggregate_targets.each do |one|
            hmap = Hash.new
            one.pod_targets.each do |target|
              target.public_header_mappings_by_file_accessor.each do |facc, headers|
                headers.each do |key, value|
                  value.each do |path|
                    pn = Pathname.new(path)
                    name = pn.basename.to_s
                    dirname = pn.dirname.to_s + '/'
                    # construct hmap hash info
                    path_info = Hash['suffix' => name, 'prefix' => dirname]
                    # import with quote
                    hmap[name] = path_info
                    # import with angle bracket
                    hmap["#{target.name}/#{name}"] = path_info
                  end
                end
              end
            end

            unless hmap.empty?
              path = "#{post_context.sandbox_root + "/#{one.name}-hmap.json"}"
              path_hmap = "#{post_context.sandbox_root + "/#{one.name}.hmap"}"
              # write hmap json to file
              File.open(path, 'w') { |file| file << hmap.to_json }
              # json to hmap
              system("hmap convert #{path} #{path_hmap}")
              # delete json file
              File.delete(path)

              # override xcconfig
              one.xcconfigs.each do |config_name, config_file|
                # puts "config_file == #{config_file} \n\r"
                config_file << Hash['OTHER_CFLAGS' => "#{"-I ${PODS_ROOT}/#{one.name}.hmap"}"]
                config_file << Hash['OTHER_SWIFT_FLAGS' => "#{"-Xcc -I${PODS_ROOT}/#{one.name}.hmap"}"]
                config_file.remove_header_search_path
                xcconfig_path = one.xcconfig_path(config_name)
                config_file.save_as(xcconfig_path)
              end

            end
          end
      end

    end
  end
end
