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
require_relative 'utils'


##### CONFIGURATION #####

@json_file = '../data/commits.js'

# Configure logger.
logger = Logger.new(STDOUT)
logger.level = Logger::WARN


##### MAIN #####

# Parse command line options.
options = Utils.parse_command_line_options()

# Find git repos to inspect.
repos = Utils.get_git_repos(path: options[:path])
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

# Regenerate monthly commits.
puts "===== Monthly commits ====="
puts ""
git_parser.get_month_scale.each do |frame|
  key = sprintf('%s-%02d', frame[0], frame[1])
  puts key + ": " + git_parser.monthly_commits[key].to_s
end
puts ""
monthly_commits_json = git_parser.get_monthly_commits_json
File.open(@json_file, 'w') { |file| file.write(monthly_commits_json) }
puts "Re-generated #{@json_file}."
puts ""
