module Middleman
  module Cli
    class BuildBefore < Thor
      include Thor::Actions

      no_commands do
        def build

        end
      end

    end
  end
end