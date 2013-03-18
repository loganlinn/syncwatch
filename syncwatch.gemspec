# -*- encoding: utf-8 -*-
require File.expand_path('../lib/syncwatch', __FILE__)

Gem::Specification.new do |s|
  s.name = 'syncwatch'
  s.authors = ['Logan Linn']
  s.description = %q{Simple CLI tool to rsync directories after file system changes}
  s.summary = s.description
  s.email = 'logan@loganlinn.com'
  s.homepage = 'https://github.com/loganlinn/syncwatch'
  s.executables = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.files = `git ls-files`.split("\n")
  s.require_paths = ['lib']
  s.version = SyncWatch::VERSION

  s.add_dependency 'rb-fsevent'
end
