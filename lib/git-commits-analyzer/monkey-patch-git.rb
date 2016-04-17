# The git gem doesn't currently support commits adding submodules when running
# "git ls-tree". I have opened https://github.com/schacon/ruby-git/pull/284 to
# fix it, but in the meantime, this monkey patch allows analyzing repositories
# with submodules.

module Git

  class Lib

    def ls_tree(sha)
      # Add 'commit' to the list of valid types.
      #data = {'blob' => {}, 'tree' => {}}
      data = {'blob' => {}, 'tree' => {}, 'commit' => {}}

      command_lines('ls-tree', sha).each do |line|
        (info, filenm) = line.split("\t")
        (mode, type, sha) = info.split
        data[type][filenm] = {:mode => mode, :sha => sha}
      end

      data
    end

  end

end
