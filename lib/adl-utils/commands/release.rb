require 'middleman-core/cli'
require 'thor'
# require 'pry'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli
    #
    # Create Release CLI Script.
    #
    class Release < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :release

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc 'release [options]', Middleman::ADLUTILS::RELEASE_DESC
      method_option 'build_before', type: :boolean, aliases: '-b', desc: 'Build before creating the release'
      method_option 'environment', default: 'dev', aliases: '-e', type: :string, desc: 'Environment (Default: dev)'
      method_option 'platform', aliases: '-p', default: 'icongo', type: :string, desc: 'version (icongo or hybris)'

      def release
        build_before
        process
      end

      protected

      def revision
        rev = options['environment'] || ENV['REV']
        rev = 'dev' if rev.nil?
        rev
      end

      def version
        options['platform'] || ENV['VER']
      end

      def build_before
        if yes?('== Do you want to build your project first ?')
          run("VER=#{version} REV=#{revision} middleman build --clean", verbose: false) || exit(1)
        end
      end

      def print_usage_and_die(message)
        usage_path    = File.join(File.dirname(__FILE__), '..', '..', 'USAGE')
        usage_message = File.read(usage_path)
        raise Error, "ERROR: #{message}\n#{usage_message}"
      end

      def process
        say 'Pushing to github...'
        release_version = ask('Specify a release version (needs to be formated like vx.x.x where x is a numeric value): ')
        description_raw = ask('Please type a description: ')
        description = description_raw.gsub(/\n/, '"\0"')
        run(`git tag -a v#{release_version} -m "#{description}"`)
        run("git push origin v#{release_version}")
      end
    end
  end
end
