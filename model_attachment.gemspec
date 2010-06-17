require File.expand_path("../lib/model_attachment/version", __FILE__)


Gem::Specification.new do |s|
  s.name = "model_attachment"
  s.version = ModelAttachment::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Steve Walker"]
  s.email = ["swalker@walkertek.com"]
  s.homepage = "http://github.com/stw/model_attachment"
  s.summary = "A simple file attachment gem"
  s.description = "Simple file attachment gem"

  s.required_rubygems_version = ">= 1.3.6"

  # lol - required for validation
  s.rubyforge_project = "model_attachment"

  # If you have other dependencies, add them here
  s.add_dependency "aws-s3"
  
  # If you need to check in files that aren't .rb files, add them here
  s.files = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.rdoc", "Gemfile", "Rakefile", "test/**/*.rb", "test/assets/*"]
  s.require_path = 'lib'

  # If you need an executable, add it here
  # s.executables = ["newgem"]

  # If you have C extensions, uncomment this line
  # s.extensions = "ext/extconf.rb"
end

