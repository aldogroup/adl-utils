require 'middleman-core/cli'
require 'thor'
# require 'pry'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli

    #
    # Create Daemon CLI Script.
    #
    class Daemon < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :daemon

      def self.exit_on_failure?
        true
      end

      desc 'daemon [options]', Middleman::ADLUTILS::DAEMON_DESC
      method_option 'start', type: :boolean, default: false, desc: 'Start middleman as daemon'
      method_option 'stop', type: :boolean, default: false, desc: 'stop the daemon'
      method_option 'restart', type: :boolean, default: false, desc: 'restart the daemon'

      def daemon
        if options['stop']
          stop_daemon
        elsif options['restart']
          restart_daemon
        elsif options['start']
          start_daemon
        else
          puts set_color '== You need to specify an option to run middleman as daemon.\nPlease use: middleman daemon --help', :red
        end
      end

      protected

      def godfile_template
        "#{File.join(File.dirname(__FILE__), '/data/')}middleman.god"
      end

      def start_daemon
        # godfile_template =
        puts set_color '== Starting Middleman with icongo settings using dev environment', :yellow
        run("god start middleman -c #{godfile_template}", verbose: false) || exit(1)
        puts set_color '== Middleman Server is running at: http://localhost:1337/', :green
      end

      def stop_daemon
        run("god stop middleman -c #{godfile_template}", verbose: false) || exit(1)
      end

      def restart_daemon
        run("god restart middleman -c #{godfile_template}", verbose: false) || exit(1)
      end
    end
  end
end
