# Parse .gitstatsignore and test if filenames match entries.
#
# Example:
#
#   gitstatsignore = GitStatsIgnore.new(filename: filename)
#
class GitStatsIgnore
  # Public: Returns a list of patterns found in the .gitstatsignore file.
  attr_reader :patterns

  # Initialize a new GitStatsIgnore object.
  #
  # @param content [String] The content of a .gitstatsignore file.
  #
  # Example:
  #
  #   gitstatsignore = GitStatsIgnore.new(content: content)
  #
  def initialize(content:)
    @content = content
    @patterns = []

    if content
      @patterns = content.split(/[\r\n]+/)
        .grep(/^[^#]/)                  # Ignore comments.
        .map! { |x|
          x.gsub(/(^\s+|\s+$)/, '')     # Trim any whitespace.
           .gsub(/\\/, '/')             # Normalize folder hierarchy separator on "/".
           .gsub(/\*/, '[^\/]+')        # Expand * into pattern matching a file or directory.
           .sub(/^\//, '^/')            # Expand leading / into a match at the root of the repo.
           .sub(/^(?!\^)/, '^.*/')      # Insert boundary at beginning of patterns.
           .sub(/(?<!\/)$/, '(?:\/|$)') # Insert boundary at the end of patterns.
        }
    end
  end

  # Determine if a relative path to the repo matches a pattern in this
  # .gitstatsignore file.
  #
  # @param filename [String] The filename of the file to check against patterns.
  #
  # Example:
  #
  #   matches = gitstatsignore.matches_filename('test.txt')
  #
  def matches_filename(filename:)
    filename = filename
      .gsub(/\\/, '/')     # Normalize folder hierarchy separator on "/".
      .sub(/^(?!\/)/, '/') # Indicate root of repository.

    for pattern in @patterns
      if filename.match(pattern)
        return true
      end
    end

    return false
  end
end
