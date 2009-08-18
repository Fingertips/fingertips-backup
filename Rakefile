require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name        = "fingertips-backup"
    s.description = "A simple tool to backup MySQL databases and files to an Amazon EBS instance through an EC2 instance."
    s.summary     = "A simple tool to backup a webserver."
    s.homepage    = "http://fingertips.github.com"
    
    s.authors = ["Eloy Duran"]
    s.email   = "eloy@fngtps.com"
    
    s.add_dependency 'Fingertips-executioner'
    s.add_dependency 'aws-s3'
  end
rescue LoadError
end