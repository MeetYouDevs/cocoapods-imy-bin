require 'json'
require 'digest'
require 'time'

module CBin
  class IncrementHelper
    MANIFEST_VERSION = 1
    MANIFEST_FILENAME = '.bin-manifest.json'

    def initialize(root_dir)
      @root_dir = root_dir.to_s
      @manifest_path = File.join(@root_dir, MANIFEST_FILENAME)
      @manifest = load_manifest
    end

    attr_reader :manifest_path

    # Check if pod needs rebuild
    def needs_build?(spec, config_env, build_configuration)
      key = pod_key(spec)
      entry = @manifest['pods'][key]
      return true unless entry
      return true if entry['status'] == 'failed'
      return true if entry['version'] != spec.version.to_s
      return true if entry['config_env'] != config_env
      return true if entry['build_configuration'] != build_configuration
      return true if entry['source_hash'] != source_hash(spec)

      # Check outputs still exist
      outputs = entry['outputs'] || []
      return true if outputs.empty?
      return true unless outputs.all? { |path| File.exist?(path) }

      false
    end

    # Record successful build
    def record_success(spec, config_env, build_configuration, outputs)
      key = pod_key(spec)
      @manifest['pods'][key] = {
        'pod_name' => spec.name,
        'version' => spec.version.to_s,
        'source_hash' => source_hash(spec),
        'config_env' => config_env,
        'build_configuration' => build_configuration,
        'status' => 'success',
        'outputs' => outputs.map(&:to_s),
        'built_at' => Time.now.iso8601
      }
      save_manifest
    end

    # Record failed build
    def record_failure(spec, config_env, build_configuration)
      key = pod_key(spec)
      @manifest['pods'][key] = {
        'pod_name' => spec.name,
        'version' => spec.version.to_s,
        'status' => 'failed',
        'config_env' => config_env,
        'build_configuration' => build_configuration,
        'built_at' => Time.now.iso8601
      }
      save_manifest
    end

    # Clear all entries
    def clear!
      @manifest = new_manifest
      save_manifest
    end

    def entries
      @manifest['pods']
    end

    private

    def pod_key(spec)
      spec.name
    end

    def source_hash(spec)
      if spec.defined_in_file && File.exist?(spec.defined_in_file.to_s)
        Digest::SHA256.hexdigest(File.read(spec.defined_in_file.to_s))[0..15]
      else
        Digest::SHA256.hexdigest(spec.to_json)[0..15]
      end
    end

    def load_manifest
      if File.exist?(@manifest_path)
        data = JSON.parse(File.read(@manifest_path))
        if data['manifest_version'] == MANIFEST_VERSION
          data
        else
          Pod::UI.warn "增量 manifest 版本不匹配 (#{data['manifest_version']} != #{MANIFEST_VERSION})，将全量重建"
          new_manifest
        end
      else
        new_manifest
      end
    rescue JSON::ParserError
      Pod::UI.warn "增量 manifest 文件损坏，将全量重建"
      new_manifest
    end

    def new_manifest
      {
        'manifest_version' => MANIFEST_VERSION,
        'created_at' => Time.now.iso8601,
        'pods' => {}
      }
    end

    def save_manifest
      @manifest['updated_at'] = Time.now.iso8601
      File.open(@manifest_path, 'w') { |f| f.write(JSON.pretty_generate(@manifest)) }
    end
  end
end
