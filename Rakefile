require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'model_attachment'

desc 'Default: run unit tests.'
task :default => [:clean, :test]

desc 'Test the model_attachment plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Start an IRB session with all necessary files required.'
task :shell do |t|
  chdir File.dirname(__FILE__)
  exec 'irb -I lib/ -I lib/model_attachment -r rubygems -r active_record -r tempfile -r init'
end

desc 'Generate documentation for the model_attachment plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'ModelAttachment'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Update documentation on website'
task :sync_docs => 'rdoc' do
  `rsync -ave ssh doc/ steve@rsweb2:/var/sites/stephenwalker/shared/system/docs/model_attachment`
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "tmp"
  FileUtils.rm_rf "pkg"
  FileUtils.rm "test/debug.log" rescue nil
  FileUtils.rm "test/model_attachment.db" rescue nil
  Dir.glob("model_attachment-*.gem").each{|f| FileUtils.rm f }
end

include_file_globs = ["README*",
                      "LICENSE",
                      "Rakefile",
                      "init.rb",
                      "Manifest.txt",
                      "{generators,lib,tasks,test}/**/*"]

exclude_file_globs = ["test/amazon.yml",
                      "test/test.log"]

spec = Gem::Specification.new do |s| 
  s.name              = "model_attachment"
  s.description       = "Simple file attachment for ActiveRecord models"
  s.version           = ModelAttachment::VERSION
  s.author            = "Steve Walker"
  s.email             = "steve@blackboxweb.com"
  s.homepage          = "http://github.com/stw/model_attachment"
  s.platform          = Gem::Platform::RUBY
  s.summary           = "Attach files to ActiveRecord models and run commands on images"
  s.files             = FileList[include_file_globs].to_a - FileList[exclude_file_globs].to_a
  s.require_path      = "lib"
  s.test_files        = FileList["test/**/test_*.rb"].to_a
  s.rubyforge_project = "model_attachment"
  s.has_rdoc          = true
  s.extra_rdoc_files  = FileList["README*"].to_a
  s.rdoc_options << '--line-numbers' << '--inline-source'
  s.requirements << "ImageMagick"
  s.add_development_dependency 'sqlite3-ruby'
  s.add_development_dependency 'activerecord'
end

desc "Print a list of the files to be put into the gem"
task :manifest => :clean do
  spec.files.each do |file|
    puts file
  end
end
 
desc "Generate a gemspec file for GitHub"
task :gemspec => :clean do
  File.open("#{spec.name}.gemspec", 'w') do |f|
    f.write spec.to_ruby
  end
end 

desc "Build the gem into the current directory"
task :gem => :gemspec do
  `gem build #{spec.name}.gemspec`
end
