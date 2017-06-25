require 'date'
require 'git'
require 'git_diff_parser'
require 'json'

# Monkey patch for the git gem.
# See https://github.com/schacon/ruby-git/pull/284 for more details.
require 'git-commits-analyzer/monkey-patch-git'

# Parse git logs for language and commit metadata.
#
# Example:
#
#   git_commits_analyzer = GitCommitsAnalyzer.new(logger: logger, author: author)
#
class GitCommitsAnalyzer
  # Public: Returns a hash of commit numbers broken down by month.
  attr_reader :commits_by_month

  # Public: Returns the total number of commits belonging to the author
  # specified.
  attr_reader :commits_total

  # Public: Returns the number of lines added/removed broken down by language.
  attr_reader :lines_by_language

  # Public: Returns the tally of commits broken down by hour of the day.
  attr_reader :commit_hours

  # Public: Returns the tally of commits broken down by day.
  attr_reader :commit_days

  # Public: Returns the tally of commits broken down by weekday and hour.
  attr_reader :commit_weekdays_hours

  # Public: Returns the lines added/changed by month.
  attr_reader :lines_by_month

  # Public: Returns information about the analysis process.
  attr_reader :analysis_metadata

  # Initialize a new GitParser object.
  #
  # @param logger [Object] A logger object to display git errors/warnings.
  # @param author [String] The email of the git author for whom we should compile the metadata.
  #
  def initialize(logger:, author:)
    @logger = logger
    @author = author
    @commits_by_month = {}
    @commits_by_month.default = 0
    @commits_total = 0
    @lines_by_language = {}
    @commit_hours = 0.upto(23).map{ |x| [x, 0] }.to_h
    @commit_days = {}
    @commit_days.default = 0
    @commit_weekdays_hours = {}
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].each do |weekday|
      @commit_weekdays_hours[weekday] = {}
      0.upto(23).each do |hour|
        @commit_weekdays_hours[weekday][hour] = 0
      end
    end
    @lines_by_month = {}
    @analysis_metadata = {}
    @analysis_metadata['started_at'] = Time.now.to_i
    @analysis_metadata['repositories_analyzed'] = 0
    @analysis_metadata['ms_spent'] = 0
  end

  # Determine if the file is a common library that shouldn't get counted
  # towards contributions.
  #
  # @param filename [String] The name of the file to analyze.
  #
  # @return [Bool] A boolean indicating if the file is a common library.
  #
  # Example:
  #
  #   git_commits_analyzer.is_library(filename: path)
  #
  def self.is_library(filename:)
    case filename
    when /jquery-ui-\d+\.\d+\.\d+\.custom(?:\.min)?\.js$/
      return true
    when /jquery-\d+\.\d+\.\d+(?:\.min)?\.js$/
      return true
    when /jquery\.datepick(?:\.min)?\.js$/
      return true
    when /chart\.min\.js$/
      return true
    when /jquery\.js$/
      return true
    when /jquery-loader\.js$/
      return true
    when /qunit\.js$/
      return true
    when /d3\.v3(?:\.min)?\.js$/
      return true
    when /automysqlbackup(?:_default\.conf)?$/
      return true
    else
      return false
    end
  end

  # Determine the type of a file at the given revision of a repo.
  #
  # @param filename [String] The name of the file to analyze.
  # @param sha      [String] The commit ID.
  # @param git_repo [Object] A git repo object corresponding to the underlying repo.
  #
  # @return [String] A string corresponding to the language of the file.
  #
  # Example:
  #
  #   language = git_commits_analyzer.determine_language(filename: patch.file, sha: commit.sha, git_repo: git_repo)
  #
  def self.determine_language(filename:, sha:, git_repo:)
    return nil if filename == 'LICENSE'

    # First try to match on known extensions.
    case filename
    when /\.xml$/i
      return 'XML'
    when /\.go$/i
      return 'Golang'
    when /\.(pl|pm|t|cgi|pod|run)$/i
      return 'Perl'
    when /\.(?:rb|gemspec)$/
      return 'Ruby'
    when /(?:\/|^)Rakefile$/
      return 'Ruby'
    when /\.md$/
      return 'Markdown'
    when /\.json$/
      return 'JSON'
    when /\.(yml|yaml)$/
      return 'YAML'
    when /\.?(perlcriticrc|githooksrc|ini|editorconfig|gitconfig)$/
      return 'INI'
    when /\.css$/
      return 'CSS'
    when /\.(tt2|html)$/
      return 'HTML'
    when /\.sql$/
      return 'SQL'
    when /\.py$/
      return 'Python'
    when /\.js$/
      return 'JavaScript'
    when /\.c$/
      return 'C'
    when /\.sh$/
      return 'bash'
    when /(bash|bash_\w+)$/
      return 'bash'
    when /\.?(SKIP|gitignore|txt|csv|vim|gitmodules|gitattributes|jshintrc|gperf|vimrc|psqlrc|inputrc|screenrc|curlrc|wgetrc|selected_editor|dmrc|netrc)$/
      return 'Text'
    when /(?:\/|^)(?:LICENSE|LICENSE-\w+)$/
      return nil
    when /\.(?:0|1|VimballRecord)$/
      return nil
    when /^vim\/doc\/tags$/
      return nil
    when /(?:\/|^)(?:README|MANIFEST|Changes|Gemfile|Gemfile.lock|CHANGELOG)$/
      return 'Text'
    end

    # Next, retrieve the file content and infer from that.
    begin
      content = git_repo.show(sha, filename)
    rescue
      pp "#{$!}"
    end
    return nil if content == nil || content == ''

    first_line = content.split(/\n/)[0] || ''
    case first_line
    when /perl$/
      return 'Perl'
    when /ruby$/
      return 'Ruby'
    when /^\#!\/usr\/bin\/bash$/
      return 'Ruby'
    end

    # Fall back on the extension in last resort.
    extension = /\.([^\.]+)$/.match(filename)
    return filename if extension.nil?
    return nil if extension[0] == 'lock'
    return extension[0]
  end

  # Parse the git logs for a repo.
  #
  # @param repo [Object] A git repo object corresponding to the underlying repo.
  #
  # @return [NilClass]
  #
  # Note: this method adds the metadata extracted for this repo to the instance
  # variables collecting commit metadata.
  #
  # Example:
  #
  #   git_commits_analyzer.parse_repo(repo: repo)
  #
  def parse_repo(repo:)
    parse_start = Time.now

    # Support both standard and bare/mirror git repositories.
    git_repo = if File.directory?(File.join(repo, '.git'))
      then Git.open(repo, log: @logger)
      else Git.bare(repo, log: @logger)
      end

    # Note: override the default of 30 for count(), nil gives the whole git log
    # history.
    git_repo.log(count = nil).each do |commit|
      # Only include the authors specified on the command line.
      next if !@author.include?(commit.author.email)

      # Parse commit date and update the corresponding stats.
      commit_datetime = DateTime.parse(commit.author.date.to_s)
      commit_hour = commit_datetime.hour
      @commit_hours[commit_hour] += 1
      commit_day = commit_datetime.strftime('%Y-%m-%d')
      @commit_days[commit_day] += 1
      commit_weekday = commit_datetime.strftime('%a')
      @commit_weekdays_hours[commit_weekday][commit_hour] += 1

      # Note: months are zero-padded to allow easy sorting, even if it's more
      # work for formatting later on.
      commit_month = commit.date.strftime("%Y-%m")

      # Parse diff and analyze patches to detect language.
      diff = git_repo.show(commit.sha)
      diff.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

      file_properties = git_repo.ls_tree(['-r', commit.sha])

      languages_in_commit = {}
      patches = GitDiffParser.parse(diff)
      patches.each do |patch|
        # Skip submodules.
        next if file_properties['commit'].has_key?(patch.file);

        # Skip symlinks.
        next if file_properties['blob'].has_key?(patch.file) &&
          (file_properties['blob'][patch.file][:mode] == '120000')

        # Skip libraries.
        next if self.class.is_library(filename: patch.file)

        body = patch.instance_variable_get :@body
        language = self.class.determine_language(filename: patch.file, sha: commit.sha, git_repo: git_repo)
        next if language.nil?
        @lines_by_language[language] ||=
        {
          'added'   => 0,
          'deleted' => 0,
          'commits' => 0,
        }
        languages_in_commit[language] = true

        @lines_by_month[commit_month] ||=
        {
          'added'   => 0,
          'deleted' => 0,
        }

        body.split(/\n/).each do |content|
          if (/^[+-]/.match(content) && !/^[+-]\s+$/.match(content))
            if (/^\+/.match(content))
              @lines_by_language[language]['added'] += 1
              @lines_by_month[commit_month]['added'] += 1
            elsif (/^\-/.match(content))
              @lines_by_language[language]['deleted'] += 1
              @lines_by_month[commit_month]['deleted'] += 1
            end
          end
        end
      end

      languages_in_commit.keys.each do |language|
        @lines_by_language[language]['commits'] += 1
      end

      # Add to stats for monthly commit count.
      @commits_by_month[commit_month] += 1

      # Add to stats for total commits count.
      @commits_total += 1
    end

    @analysis_metadata['repositories_analyzed'] += 1
    @analysis_metadata['ms_spent'] += ((Time.now - parse_start)*1000.0).to_i

    nil
  end

  # Get a range of months from the earliest commit to the latest.
  #
  # @return [Array<String>] An array of "YYYY-MM" strings.
  #
  # Example:
  #
  #   month_scale = git_commits_analyzer.get_month_scale()
  #
  def get_month_scale()
    month_scale = []
    commits_start = @commits_by_month.keys.sort.first.split('-').map { |x| x.to_i }
    commits_end = @commits_by_month.keys.sort.last.split('-').map { |x| x.to_i }
    commits_start[0].upto(commits_end[0]) do |year|
      1.upto(12) do |month|
        next if month < commits_start[1] && year == commits_start[0]
        next if month > commits_end[1] && year == commits_end[0]
        month_scale << [year, month]
      end
    end

    return month_scale
  end

  # Generate a JSON representation of the parsed data.
  #
  # @param pretty [Bool] True to output indented JSON, false for the most compact output.
  #
  # @return [String] A JSON string.
  #
  # Example:
  #
  #   json = git_commits_analyzer.to_json(pretty: false)
  #
  def to_json(pretty: true)
    formatted_commits_by_month = []
    formatted_lines_by_month = []
    month_names = Date::ABBR_MONTHNAMES
    self.get_month_scale.each do |frame|
      display_key = month_names[frame[1]] + '-' + frame[0].to_s
      data_key = sprintf('%s-%02d', frame[0], frame[1])

      count = @commits_by_month[data_key]
      formatted_commits_by_month << {
        month: display_key,
        commits: count.to_i,
      }

      month_added_lines = 0
      month_deleted_lines = 0
      if @lines_by_month.key?(data_key)
        month_added_lines = @lines_by_month[data_key]['added'].to_i
        month_deleted_lines = @lines_by_month[data_key]['deleted'].to_i
      end
      formatted_lines_by_month << {
        month: display_key,
        added: month_added_lines,
        deleted: month_deleted_lines,
      }
    end

    data =
      {
        commits_total: @commits_total,
        commits_by_month: formatted_commits_by_month,
        commits_by_hour: @commit_hours,
        commits_by_day: @commit_days,
        commit_by_weekday_hour: @commit_weekdays_hours,
        lines_by_language: @lines_by_language,
        lines_by_month: formatted_lines_by_month,
        analysis_metadata: @analysis_metadata,
      }

    if pretty
      JSON.pretty_generate(data)
    else
      JSON.generate(data)
    end
  end
end
