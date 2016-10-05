require 'optparse'

# Supporting functions for the command-line utility.
#
# Examples:
#
#   require 'git-commits-analyzer/utils'
#   options = Utils.parse_command_line_options()
#   repos = Utils.get_git_repos(path)
#
class Utils
  # Parse supported command line options.
  #
  # @return [Hash] A hash of options/values.
  #
  def self.parse_command_line_options()
    options = {}
    OptionParser.new do |opts|
      opts.banner = 'Usage: inspect_contributions.rb [options]'
      options[:authors] = []

      # Parse path.
      opts.on('-p', '--path PATH', 'Specify a path to search for git repositories under') do |path|
        options[:path] = path
      end

      # Parse authors.
      opts.on('-a', '--author EMAIL', 'Include this author in statistics') do |email|
        options[:authors] << email
      end

      # Parse output directory.
      opts.on('-p', '--output PATH', 'Specify a path to output files with collected data') do |output|
        options[:output] = output
      end

      # Show usage
      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end.parse!

    # Check mandatory options.
    raise OptionParser::MissingArgument, '--author' if options[:authors].empty?
    raise OptionParser::MissingArgument, '--output' if options[:output].nil?
    raise OptionParser::MissingArgument, '--path' if options[:path].nil?

    return options
  end

  # Retrieve the list of git repositories amongst the subdirectories of a given
  # directory.
  #
  # @param path [String] The path of the directory to inspect.
  #
  # @return [Array<String>] An array of directory names that have a git repository inside.
  #
  def self.get_git_repos(path:)
    repos = []
    Dir.glob(File.join(path, '*')) do |dir|
      # Skip files.
      next if !File.directory?(dir)

      # Skip directories without .git subdirectory (shortcut to identify repos
      # with a working dir) or without a HEAD file (shortcut to identify bare
      # git repositories).
      next if !File.directory?(File.join(dir, '.git')) && !File.file?(File.join(dir, 'HEAD'))

      repos << dir
    end

    return repos
  end
end
