Gem::Specification.new do |s|
  s.name        = 'git-commits-analyzer'
  s.version     = '0.1.0'
  s.date        = '2016-03-12'
  s.summary     = 'Analyze git commits'
  s.description = 'Parse git repos and collect commit statistics/data for a given author.'
  s.authors     = ['Guillaume Aubert']
  s.email       = 'aubertg@cpan.org'
  s.homepage    = 'http://rubygems.org/gems/'
  s.license     = 'GPLv3'

  s.files       = [
    'lib/git_parser.rb',
    'lib/utils.rb',
  ]
  s.executables << 'analyze_commits'
end
