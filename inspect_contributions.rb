#!/usr/bin/env ruby

# Gems.
require 'date'
require 'git'
require 'git_diff_parser'
require 'logger'
require 'optparse'
require 'pp'
require 'time'

# Internal classes.
require_relative 'git_parser'


##### CONFIGURATION #####

@json_file = '../data/commits.js'

# Configure logger.
logger = Logger.new(STDOUT)
logger.level = Logger::WARN


##### FUNCTIONS #####

def parse_command_line_options()
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: inspect_contributions.rb [options]"
    options[:authors] = []

    # Parse path.
    opts.on("-p", "--path PATH", "Specify a path to search for git repositories under") do |path|
      options[:path] = path
    end

    # Parse authors.
    opts.on("-a", "--author EMAIL", "Include this author in statistics") do |email|
      options[:authors] << email
    end

    # Show usage
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end.parse!

  # Check mandatory options.
  raise OptionParser::MissingArgument, '--author' if options[:authors].length == 0
  raise OptionParser::MissingArgument, '--path' if options[:path].nil?

  return options
end

def get_git_repos(path:)
  repos = []
  Dir.glob(File.join(path, '*')) do |dir|
    # Skip files.
    next if !File.directory?(dir)

    # Skip directories without .git subdirectory (shortcut to identify repos).
    next if !File.directory?(File.join(dir, '.git'))

    repos << dir
  end

  return repos
end


##### MAIN #####

# Parse command line options.
options = parse_command_line_options()

# Find git repos to inspect.
repos = get_git_repos(path: options[:path])
puts "Found " + repos.length.to_s + " repos to inspect."
puts ""

# Inspect git repos.
puts "===== Inspecting repos ====="
puts ""
git_parser = GitParser.new(logger: logger, author: options[:authors])
repos.sort.each do |repo|
  puts "Inspecting repo " + repo
  git_parser.parse_repo(repo: repo)
  #break
end
puts ""
pp git_parser.lines_by_language

# Display sanity check.
puts "Found #{git_parser.total_commits} commits for author(s) " + options[:authors].join(', ')
puts ""
exit if git_parser.monthly_commits.keys.length == 0

# Display statistics.
puts "===== Statistics ====="
puts ""
git_parser.get_month_scale.each do |frame|
  key = sprintf('%s-%02d', frame[0], frame[1])
  puts key + ": " + git_parser.monthly_commits[key].to_s
end
puts ""

# Generate JSON for monthly commits.
puts "===== JSON output ====="
puts ""
monthly_commits_json = git_parser.get_monthly_commits_json
File.open(@json_file, 'w') { |file| file.write(monthly_commits_json) }
puts "Re-generated #{@json_file}."
puts ""
