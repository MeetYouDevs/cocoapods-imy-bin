

require 'cocoapods-imy-bin/native/specification'

module Pod
  class Specification
    class Linter
      # !@group Lint steps

      # Checks that the spec's root name matches the filename.
      #
      # @return [void]
      #
      def validate_root_name
        if spec.root.name && file
          acceptable_names = Specification::VALID_EXTNAME.map { |extname| "#{spec.root.name}#{extname}" }
          names_match = acceptable_names.include?(file.basename.to_s)
          unless names_match
            results.add_error('name', 'The name of the spec should match the ' \
                              'name of the file.')
          end
        end
      end
    end
  end
end
