module Middleman
  module Cli
    #
    # Build Before action
    #
    class BuildBefore < Thor
      include Thor::Actions

      no_commands do
        def build(rev,ver)
          if yes?('== Do you want to build your project first ?')
             run("VER=#{ver} REV=#{rev} middleman build --clean", verbose: false) || exit(1)
          end
        end
      end

    end
  end
end
