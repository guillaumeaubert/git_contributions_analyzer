# Public: parse git logs for language and commit metadata.
#
# Examples:
#
#   git_parser = GitParser.new(logger: logger, author: author)
#
class GitParser
  # Public: Returns a hash of commit numbers broken down by month.
  attr_reader :monthly_commits

  # Public: Returns the total number of commits belonging to the author
  # specified.
  attr_reader :total_commits

  # Public: Returns the number of lines added/removed broken down by language.
  attr_reader :lines_by_language

  # Public: Initialize new GitParser object.
  #
  # logger - A logger object to display git errors/warnings.
  # author - The email of the git author for whom we should compile the metadata.
  #
  def initialize(logger:, author:)
    @logger = logger
    @author = author
    @monthly_commits = {}
    @monthly_commits.default = 0
    @total_commits = 0
    @lines_by_language = {}
  end

  # Public: Determine the type of a file at the given revision of a repo.
  #
  # filename - The name of the file to analyze.
  # sha      - The commit ID.
  # git_repo - A git repo object corresponding to the underlying repo.
  #
  # Returns a string corresponding to the language of the file.
  #
  def self.determine_language(filename:, sha:, git_repo:)
    return nil if filename == 'LICENSE'

    # First try to match on known extensions.
    case filename
    when /\.(pl|pm|t|cgi|pod|run)$/i
      return 'Perl'
    when /\.rb$/
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
    when /\.?(SKIP|gitignore|txt|csv|vim|gitmodules|gitattributes|jshintrc|gperf|vimrc|psqlrc|inputrc|screenrc)$/
      return 'Text'
    when /^(README|MANIFEST|Changes)$/
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
    end

    # Fall back on the extension in last resort.
    extension = /\.([^\.]+)$/.match(filename)
    return filename if extension.nil?
    return extension[0]
  end

  # Public: Parse the git logs for a repo.
  #
  # repo - A git repo object corresponding to the underlying repo.
  #
  # This method adds the metadata extracted for this repo to the instance
  # variables collecting commit metadata.
  #
  def parse_repo(repo:)
    git_repo = Git.open(repo, :log => @logger)

    # Note: override the default of 30 for count(), nil gives the whole git log
    # history.
    git_repo.log(count = nil).each do |commit|
      # Only include the authors specified on the command line.
      next if !@author.include?(commit.author.email)

      # Parse diff and analyze patches to detect language.
      diff = commit.diff_parent.to_s
      diff.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

      patches = GitDiffParser.parse(diff)
      patches.each do |patch|
        body = patch.instance_variable_get :@body
        language = self.class.determine_language(filename: patch.file, sha: commit.sha, git_repo: git_repo)
        next if language == nil
        @lines_by_language[language] ||=
        {
          'added'   => 0,
          'deleted' => 0
        }

        body.split(/\n/).each do |content|
          if (/^[+-]/.match(content) && !/^[+-]\s+$/.match(content))
            if (/^\+/.match(content))
              @lines_by_language[language]['added'] += 1
            elsif (/^\-/.match(content))
              @lines_by_language[language]['deleted'] += 1
            end
          end
        end
      end

      # Add to stats for monthly commit count.
      # Note: months are zero-padded to allow easy sorting, even if it's more
      # work for formatting later on.
      @monthly_commits[commit.date.strftime("%Y-%m")] += 1

      # Add to stats for total commits count.
      @total_commits += 1
    end
  end

  # Public: Get a range of months from the earliest commit to the latest.
  #
  # Returns an array of "YYYY-MM" strings.
  #
  def get_month_scale()
    month_scale = []
    commits_start = @monthly_commits.keys.sort.first.split('-').map { |x| x.to_i }
    commits_end = @monthly_commits.keys.sort.last.split('-').map { |x| x.to_i }
    commits_start[0].upto(commits_end[0]) do |year|
      1.upto(12) do |month|
        next if month < commits_start[1] && year == commits_start[0]
        next if month > commits_end[1] && year == commits_end[0]
        month_scale << [year, month]
      end
    end

    return month_scale
  end

  # Public: Generate a JSON representation of commits totals by month.
  #
  # Returns: a JSON string.
  #
  def get_monthly_commits_json()
    json = []
    json << 'var commits ='
    json << '['
    json << "\t// Date       Commits"
    month_names = Date::ABBR_MONTHNAMES
    self.get_month_scale.each do |frame|
      display_key = month_names[frame[1]] + '-' + frame[0].to_s
      data_key = sprintf('%s-%02d', frame[0], frame[1])
      count = @monthly_commits[data_key].to_s
      json << sprintf("\t[ \"%s\", %s ],", display_key, count.to_s.ljust(3))
    end
    json << '];'

    return json.join("\n")
  end
end
