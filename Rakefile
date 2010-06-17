require 'bundler'
Bundler.setup

#require 'rspec/core/rake_task'
#Rspec::Core::RakeTask.new(:spec)

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => [:clean, :test]

desc 'Test the model_attachment plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "tmp"
  FileUtils.rm_rf "pkg"
  FileUtils.rm "test/test.log" rescue nil
  Dir.glob("model_attachment-*.gem").each{|f| FileUtils.rm f }
end

desc 'Generate documentation for the model_attachment plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'ModelAttachment'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

gemspec = eval(File.read("model_attachment.gemspec"))

task :gem   => "#{gemspec.full_name}.gem"
task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["model_attachment.gemspec"] do
  system "gem build model_attachment.gemspec"
  system "gem install model_attachment-#{ModelAttachment::VERSION}.gem"
end
