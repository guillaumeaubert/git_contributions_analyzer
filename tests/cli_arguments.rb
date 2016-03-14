require 'test/unit'

class TestCLIArguments < Test::Unit::TestCase
  def test_missing_arguments
    assert_match(
      /missing argument: --author/,
      `ruby -Ilib bin/analyze_commits 2>&1`
    )
    assert_match(
      /missing argument: --output/,
      `ruby -Ilib bin/analyze_commits --author=aubertg@cpan.org 2>&1`
    )
    assert_match(
      /missing argument: --path/,
      `ruby -Ilib bin/analyze_commits --author=aubertg@cpan.org --output=/tmp/ 2>&1`
    )
  end
end
