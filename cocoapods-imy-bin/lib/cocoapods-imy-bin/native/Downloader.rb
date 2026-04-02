require 'cocoapods-downloader'
require 'claide/informative_error'
require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    require 'cocoapods/downloader/cache'
    require 'cocoapods/downloader/request'
    require 'cocoapods/downloader/response'

    # Downloads a pod from the given `request` to the given `target` location.
    #
    # @return [Response] The download response for this download.
    #
    # @param  [Request] request
    #         the request that describes this pod download.
    #
    # @param  [Pathname,Nil] target
    #         the location to which this pod should be downloaded. If `nil`,
    #         then the pod will only be cached.
    #
    # @param  [Boolean] can_cache
    #         whether caching is allowed.
    #
    # @param  [Pathname,Nil] cache_path
    #         the path used to cache pod downloads.
    #
    def self.download(
        request,
        target,
        can_cache: true,
        cache_path: Config.instance.cache_root + 'Pods'
    )
      can_cache &&= !Config.instance.skip_download_cache

      request = preprocess_request(request)

      if can_cache
        raise ArgumentError, 'Must provide a `cache_path` when caching.' unless cache_path
        cache = Cache.new(cache_path)
        result = cache.download_pod(request)
      else
        raise ArgumentError, 'Must provide a `target` when caching is disabled.' unless target

        require 'cocoapods/installer/pod_source_preparer'
        result, = download_request(request, target)
        Installer::PodSourcePreparer.new(result.spec, result.location).prepare!
      end

      if target && result.location && target != result.location
        UI.message "Copying #{request.name} from `#{result.location}` to #{UI.path target}", '> ' do
          FileUtils.rm_rf target
          FileUtils.cp_r(result.location, target)
          file_count = Dir.glob(File.join(target, '**', '*')).select { |file| File.file?(file) }.count
          if file_count < 2
            FileUtils.rm_rf target
            FileUtils.cp_r(result.location, target)
            UI.warn "======Copying #{request.name} ==== #{target} 为空，请注意 ======== "
          end
        end
      end
      result
    end


  end
end
