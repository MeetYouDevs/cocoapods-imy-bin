

module Pod
  class Validator
    # def validate_source_url(spec)
    #   return if spec.source.nil? || spec.source[:http].nil?
    #   url = URI(spec.source[:http])
    #   return if url.scheme == 'https' || url.scheme == 'file'
    #   warning('http', "The URL (`#{url}`) doesn't use the encrypted HTTPs protocol. " \
    #           'It is crucial for Pods to be transferred over a secure protocol to protect your users from man-in-the-middle attacks. '\
    #           'This will be an error in future releases. Please update the URL to use https.')
    # end
    #
    # Perform analysis for a given spec (or subspec)
    #
    def perform_extensive_analysis(spec)
      if spec.non_library_specification?
        error('spec', "Validating a non library spec (`#{spec.name}`) is not supported.")
        return false
      end
      validate_homepage(spec)
      validate_screenshots(spec)
      validate_social_media_url(spec)
      validate_documentation_url(spec)
      validate_source_url(spec)

      platforms = platforms_to_lint(spec)

      valid = platforms.send(fail_fast ? :all? : :each) do |platform|
        UI.message "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed
        @consumer = spec.consumer(platform)
        setup_validation_environment
        begin
          create_app_project
          # download_pod
          # check_file_patterns
          # install_pod
          # validate_swift_version
          # add_app_project_import
          # validate_vendored_dynamic_frameworks
          # build_pod
          # test_pod unless skip_tests
        ensure
          tear_down_validation_environment
        end
        validated?
      end
      return false if fail_fast && !valid
      perform_extensive_subspec_analysis(spec) unless @no_subspecs
    rescue => e
      message = e.to_s
      message << "\n" << e.backtrace.join("\n") << "\n" if config.verbose?
      error('unknown', "Encountered an unknown error (#{message}) during validation.")
      false
    end

    #覆盖
    def check_file_patterns
      FILE_PATTERNS.each do |attr_name|
        next if %i(source_files resources).include? attr_name
          if respond_to?("_validate_#{attr_name}", true)
            send("_validate_#{attr_name}")
          else
            validate_nonempty_patterns(attr_name, :error)
          end
      end

      _validate_header_mappings_dir
      if consumer.spec.root?
        _validate_license
        _validate_module_map
      end
    end

    def validate_source_url(spec); end
  end
end
