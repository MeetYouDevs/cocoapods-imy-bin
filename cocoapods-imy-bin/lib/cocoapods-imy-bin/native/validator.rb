

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
      return true
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
