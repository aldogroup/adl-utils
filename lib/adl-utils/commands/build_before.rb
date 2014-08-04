module Middleman
  module Cli
    class BuildBefore < Thor
      include Thor::Actions

      no_commands do
        def build
          run("VER=hybris REV=#{ENV['REV']} middleman build --clean") || exit(1)
        end
      end

    end
  end
end