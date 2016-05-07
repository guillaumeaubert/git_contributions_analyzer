Gem::Specification.new do |s|
  s.name        = 'git-commits-analyzer'
  s.version     = '1.3.0'
  s.date        = '2016-05-07'
  s.summary     = 'Analyze git commits'
  s.description = 'Parse git repos and collect commit statistics/data for a given author.'
  s.authors     = ['Guillaume Aubert']
  s.email       = 'aubertg@cpan.org'
  s.homepage    = 'http://rubygems.org/gems/'
  s.license     = 'MIT'

  s.files       = [
    'lib/git-commits-analyzer.rb',
    'lib/git-commits-analyzer/utils.rb',
    'lib/git-commits-analyzer/monkey-patch-git.rb'
  ]
  s.executables << 'analyze_commits'
end
