# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{fingertips-backup}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Eloy Duran"]
  s.date = %q{2009-08-18}
  s.default_executable = %q{fingertips-backup}
  s.description = %q{A simple tool to backup MySQL databases and files to an Amazon EBS instance through an EC2 instance.}
  s.email = %q{eloy@fngtps.com}
  s.executables = ["fingertips-backup"]
  s.files = [
    "Rakefile",
    "VERSION.yml",
    "bin/fingertips-backup",
    "lib/backup.rb",
    "lib/ec2.rb",
    "lib/logger.rb",
    "test/backup_test.rb",
    "test/ec2_test.rb",
    "test/fixtures/attach-volume",
    "test/fixtures/config.yml",
    "test/fixtures/describe-instances",
    "test/fixtures/describe-volumes",
    "test/fixtures/run-instances",
    "test/fixtures/terminate-instances",
    "test/logger_test.rb",
    "test/test_helper.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://fingertips.github.com}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{A simple tool to backup a webserver.}
  s.test_files = [
    "test/backup_test.rb",
    "test/ec2_test.rb",
    "test/logger_test.rb",
    "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<Fingertips-executioner>, [">= 0"])
      s.add_runtime_dependency(%q<aws-s3>, [">= 0"])
    else
      s.add_dependency(%q<Fingertips-executioner>, [">= 0"])
      s.add_dependency(%q<aws-s3>, [">= 0"])
    end
  else
    s.add_dependency(%q<Fingertips-executioner>, [">= 0"])
    s.add_dependency(%q<aws-s3>, [">= 0"])
  end
end
