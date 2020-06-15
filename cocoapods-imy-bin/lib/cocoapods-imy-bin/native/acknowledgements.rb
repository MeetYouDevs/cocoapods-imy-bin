

module Pod
  module Generator
    class Acknowledgements
      def license_text(spec)
        return nil unless spec.license

        text = spec.license[:text]
        unless text
          if license_file = spec.license[:file]
            license_path = file_accessor(spec).root + license_file
            if File.exist?(license_path)
              text = IO.read(license_path)
            else
              # UI.warn "Unable to read the license file `#{license_file}` " \
              # "for the spec `#{spec}`"
            end
          elsif license_file = file_accessor(spec).license
            text = IO.read(license_file)
          end
        end
        text
      end
    end
  end
end
