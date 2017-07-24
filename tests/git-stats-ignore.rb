require 'test/unit'
require 'tempfile'
require 'git-commits-analyzer/git-stats-ignore'

# Public: test command-line arguments handling.
#
class TestGitStatsIgnore < Test::Unit::TestCase
  def test_initialize
    tests = [
      {
        content: "  \\test   \n" +
          "#test\n",
        expect: ['^/test(?:\/|$)'],
        matching:
        {
          '/test': true,
          '/test.txt': false,
          '/dir/test': false
        }
      },
      {
        content: "/test*\n",
        expect: ['^/test[^\/]+(?:\/|$)'],
        matching:
        {
          '/test.txt': true,
          '/dir/test.txt': false,
          '/tests/file.txt': true
        }
      },
      {
        content: "/test*\n" +
          "test.ini\n",
        expect:
        [
          '^/test[^\/]+(?:\/|$)',
          '^.*/test.ini(?:\/|$)'
        ],
        matching:
        {
          '/test.txt': true,
          '/test.ini': true
        }
      },
      {
        content: "test\n",
        expect: ['^.*/test(?:\/|$)'],
        matching:
        {
          '/test': true,
          '/dir/test': true,
          '/test/dir.txt': true
        }
      }
    ]

    tests.each do |test|
      gitstatsignore = nil
      assert_nothing_raised do
        gitstatsignore = GitStatsIgnore.new(content: test[:content])
      end

      assert(
        gitstatsignore.patterns == test[:expect],
        "Content:\n#{test[:content]}\n" +
        "Patterns found:\n#{gitstatsignore.patterns.inspect}\n" +
        "Expected:\n#{test[:expect]}\n"
      )

      files = test[:matching]
      files.keys.sort.each do |file|
        assert(
          gitstatsignore.matches_filename(filename: file.to_s) == files[file],
          "Content:\n#{test[:content]}\n" +
          "Patterns found:\n#{gitstatsignore.patterns.inspect}\n" +
          "File: #{file}\n" +
          "Expected: #{files[file]}\n"
        )
      end
    end
  end
end
