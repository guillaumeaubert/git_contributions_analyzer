class Utils
  def self.parse_command_line_options()
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

  def self.get_git_repos(path:)
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
end
