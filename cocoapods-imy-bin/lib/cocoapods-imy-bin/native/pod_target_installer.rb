module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # Creates the target for the Pods libraries in the Pods project and the
        # relative support files.
        #
        class PodTargetInstaller < TargetInstaller
          require 'cocoapods/installer/xcode/pods_project_generator/app_host_installer'

          # Adds a shell script phase, intended only for library targets that contain swift,
          # to copy the ObjC compatibility header (the -Swift.h file that the swift compiler generates)
          # to the built products directory. Additionally, the script phase copies the module map, appending a `.Swift`
          # submodule that references the (moved) compatibility header. Since the module map has been moved, the umbrella header
          # is _also_ copied, so that it is sitting next to the module map. This is necessary for a successful archive build.
          #
          # @param  [PBXNativeTarget] native_target
          #         the native target to add the Swift static library script phase into.
          #
          # @return [Void]
          #
          alias old_add_swift_library_compatibility_header_phase add_swift_library_compatibility_header_phase

          def add_swift_library_compatibility_header_phase(native_target)
            UI.warn("========= swift add_swift_library_compatibility_header_phase")
            if $ARGV[1] == "auto"
              UI.warn("========= auto swift add_swift_library_compatibility_header_phase")

              if custom_module_map
                raise Informative, 'Using Swift static libraries with custom module maps is currently not supported. ' \
                                 "Please build `#{target.label}` as a framework or remove the custom module map."
              end

              build_phase = native_target.new_shell_script_build_phase('Copy generated compatibility header')

              relative_module_map_path = target.module_map_path.relative_path_from(target.sandbox.root)
              relative_umbrella_header_path = target.umbrella_header_path.relative_path_from(target.sandbox.root)

              build_phase.shell_script = <<-SH.strip_heredoc
              COMPATIBILITY_HEADER_PATH="${BUILT_PRODUCTS_DIR}/Swift Compatibility Header/${PRODUCT_MODULE_NAME}-Swift.h"
              MODULE_MAP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap"

              ditto "${DERIVED_SOURCES_DIR}/${PRODUCT_MODULE_NAME}-Swift.h" "${COMPATIBILITY_HEADER_PATH}"
              ditto "${PODS_ROOT}/#{relative_module_map_path}" "${MODULE_MAP_PATH}"
              ditto "${PODS_ROOT}/#{relative_umbrella_header_path}" "${BUILT_PRODUCTS_DIR}"
              
              COPY_PATH="${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}"
              UMBRELLA_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}-umbrella.h"
              SWIFTMODULE_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.swiftmodule" 

              ditto "${MODULE_MAP_PATH}" "${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/${PRODUCT_MODULE_NAME}.modulemap"
              ditto "${COMPATIBILITY_HEADER_PATH}" "${COPY_PATH}/Swift Compatibility Header/${PRODUCT_MODULE_NAME}-Swift.h"
              ditto "${COMPATIBILITY_HEADER_PATH}" "${COPY_PATH}"
              ditto "${UMBRELLA_PATH}" "${COPY_PATH}"
              ditto "${SWIFTMODULE_PATH}" "${COPY_PATH}/${PRODUCT_MODULE_NAME}.swiftmodule"
              ditto "${SWIFTMODULE_PATH}" "${COPY_PATH}/${PRODUCT_MODULE_NAME}.swiftmodule"
              
              if [ ${PRODUCT_MODULE_NAME} != ${PRODUCT_NAME} ] ; then
                   ditto "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}-umbrella.h" "${COPY_PATH}"
                   ditto "${COPY_PATH}" "${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}"
              fi
    
              MODULE_MAP_SEARCH_PATH = "${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/${PRODUCT_MODULE_NAME}.modulemap"
              
              if [${MODULE_MAP_PATH} != ${MODULE_MAP_SEARCH_PATH}] ; then
                  printf "\\n\\nmodule ${PRODUCT_MODULE_NAME}.Swift {\\n  header \\"${COPY_PATH}/Swift Compatibility Header/${PRODUCT_MODULE_NAME}-Swift.h\\"\\n  requires objc\\n}\\n" >> "${MODULE_MAP_SEARCH_PATH}"
              fi

              printf "\\n\\nmodule ${PRODUCT_MODULE_NAME}.Swift {\\n  header \\"${COMPATIBILITY_HEADER_PATH}\\"\\n  requires objc\\n}\\n" >> "${MODULE_MAP_PATH}"

              SH
              build_phase.input_paths = %W(
              ${DERIVED_SOURCES_DIR}/${PRODUCT_MODULE_NAME}-Swift.h
              ${PODS_ROOT}/#{relative_module_map_path}
              ${PODS_ROOT}/#{relative_umbrella_header_path}
              )
              build_phase.output_paths = %W(
              ${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap
              ${BUILT_PRODUCTS_DIR}/#{relative_umbrella_header_path.basename}
              ${BUILT_PRODUCTS_DIR}/Swift\ Compatibility\ Header/${PRODUCT_MODULE_NAME}-Swift.h
            )
            else
              UI.warn("========= null swift add_swift_library_compatibility_header_phase")
              old_add_swift_library_compatibility_header_phase(native_target)
            end

          end

          #-----------------------------------------------------------------------#
        end
      end
    end
  end
end
