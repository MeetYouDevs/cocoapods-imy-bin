SKIP_UNRELEASED_VERSIONS = false

# Specify your gem's dependencies in cocoapods-imy-bin.gemspec


def cp_gem(name, repo_name, branch = 'master', path: false)
  return gem name if SKIP_UNRELEASED_VERSIONS
  opts = if path
           { :path => "../#{repo_name}" }
         else
           url = "https://github.com/CocoaPods/#{repo_name}.git"
           { :git => url, :branch => branch }
         end
  gem name, opts
end

source 'https://rubygems.org'


group :development do

  cp_gem 'cocoapods',                'cocoapods',path: 'CocoaPods'
  cp_gem 'xcodeproj',                'xcodeproj',path: 'Xcodeproj'
  cp_gem 'cocoapods-imy-bin',                'cocoapods-imy-bin',path: 'cocoapods-imy-bin'

  gem 'cocoapods-generate', '1.6.0'
  gem 'mocha'
  gem 'bacon'
  gem 'mocha-on-bacon'
  gem 'prettybacon'

end
