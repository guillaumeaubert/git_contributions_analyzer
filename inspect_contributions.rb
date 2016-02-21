#!/usr/bin/env ruby

require 'date'
require 'git'
require 'logger'
require 'optparse'
require 'pp'
require 'time'


@json_file = '../data/commits.js'

# Configure logger.
logger = Logger.new(STDOUT)
logger.level = Logger::WARN

# Parse command line options.
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

# Find git repos to inspect.
repos = []
Dir.glob(File.join(options[:path], '*')) do |dir|
  # Skip files.
  next if !File.directory?(dir)

  # Skip directories without .git subdirectory (shortcut to identify repos).
  next if !File.directory?(File.join(dir, '.git'))

  repos << dir
end
puts "Found " + repos.length.to_s + " repos to inspect."
puts ""

# Inspect git repos.
puts "===== Inspecting repos ====="
puts ""
monthly_commits = {}
monthly_commits.default = 0
total_commits = 0
repos.sort.each do |repo|
  puts "Inspecting repo " + repo
  git_repo = Git.open(repo, :log => logger)

  # Note: override the default of 30 for count(), nil gives the whole git log
  # history.
  git_repo.log(count = nil).each do |commit|
    # Only include the authors specified on the command line.
    next if !options[:authors].include?(commit.author.email)

    # Add to stats for monthly commit count.
    # Note: months are zero-padded to allow easy sorting, even if it's more
    # work for formatting later on.
    monthly_commits[commit.date.strftime("%Y-%m")] += 1

    # Add to stats for total commits count.
    total_commits += 1
  end
end
puts ""

# Display sanity check.
puts "Found #{total_commits} commits for author(s) " + options[:authors].join(', ')
puts ""
exit if monthly_commits.keys.length == 0

# Get a full list of indexes, including months without commits.
month_scale = []
commits_start = monthly_commits.keys.sort.first.split('-').map { |x| x.to_i }
commits_end = monthly_commits.keys.sort.last.split('-').map { |x| x.to_i }
commits_start[0].upto(commits_end[0]) do |year|
  1.upto(12) do |month|
    next if month < commits_start[1] && year == commits_start[0]
    next if month > commits_end[1] && year == commits_end[0]
    month_scale << [year, month]
  end
end

# Display statistics.
puts "===== Statistics ====="
puts ""
month_scale.each do |frame|
  key = sprintf('%s-%02d', frame[0], frame[1])
  puts key + ": " + monthly_commits[key].to_s
end
puts ""

# Generate JSON.
puts "===== JSON output ====="
puts ""
json = []
json << 'var commits ='
json << '['
json << "\t// Date       Commits"
month_names = Date::ABBR_MONTHNAMES
month_scale.each do |frame|
  display_key = month_names[frame[1]] + '-' + frame[0].to_s
  data_key = sprintf('%s-%02d', frame[0], frame[1])
  count = monthly_commits[data_key].to_s
  json << sprintf("\t[ \"%s\", %s ],", display_key, count.to_s.ljust(3))
end
json << '];'

# Write the new data file.
File.open(@json_file, 'w') { |file| file.write(json.join("\n")) }
puts "Re-generated #{@json_file}."
puts ""
