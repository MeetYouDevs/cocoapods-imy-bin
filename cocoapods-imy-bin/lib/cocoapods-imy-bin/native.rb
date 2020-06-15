require 'cocoapods'

if Pod.match_version?('~> 1.4')
  require 'cocoapods-imy-bin/native/podfile'
  require 'cocoapods-imy-bin/native/installation_options'
  require 'cocoapods-imy-bin/native/specification'
  require 'cocoapods-imy-bin/native/path_source'
  require 'cocoapods-imy-bin/native/analyzer'
  require 'cocoapods-imy-bin/native/installer'
  require 'cocoapods-imy-bin/native/podfile_generator'
  require 'cocoapods-imy-bin/native/pod_source_installer'
  require 'cocoapods-imy-bin/native/linter'
  require 'cocoapods-imy-bin/native/resolver'
  require 'cocoapods-imy-bin/native/source'
  require 'cocoapods-imy-bin/native/validator'
  require 'cocoapods-imy-bin/native/acknowledgements'
  require 'cocoapods-imy-bin/native/sandbox_analyzer'
  require 'cocoapods-imy-bin/native/podspec_finder'
end
