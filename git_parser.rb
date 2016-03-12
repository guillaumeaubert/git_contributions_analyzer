class GitParser
  attr_accessor :monthly_commits, :total_commits, :lines_by_language

  def initialize(logger:, author:)
    @logger = logger
    @author = author
    @monthly_commits = {}
    @monthly_commits.default = 0
    @total_commits = 0
    @lines_by_language = {}
  end

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

  # Get a full list of indexes, including months without commits.
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
