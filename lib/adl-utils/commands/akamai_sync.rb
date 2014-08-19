require 'middleman-core/cli'
require 'thor'
# require 'pry'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli
    class AkamaiSync < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :akamai_sync

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc 'akamai_sync [options]', Middleman::ADLUTILS::AKAMAI_DESC
      method_option 'build_before', type: :boolean, aliases: '-b', desc: 'Run `middleman build` before the release'
      method_option 'environment', default: 'dev', aliases: '-e', type: :string, desc: 'Environment (Default: dev)'
      method_option 'platform', aliases: '-p', default: 'icongo', type: :string, desc: 'version (icongo or hybris)'

      def akamai_sync
        build_before(options)
        FtpConfig.process(options)
      end

      protected

      def build_before(options={})
        if yes?('== Do you want to build your project first ?')
          revision = options['environment']
          version = options['platform']
          run("VER=#{version} REV=#{revision} middleman build --clean", {:verbose => false}) || exit(1)
        end
      end

      class FtpConfig < Middleman::Extension
        require 'middleman-core'
        require 'net/ftp'
        def initialize(app, options_hash={}, &block)
          # Call super to build options from the options_hash
          super
        end

        def self.filtered_files
          files = Dir.glob('**/*', File::FNM_DOTMATCH)
          files.reject { |filename| filename =~ Regexp.new('\.$') }
        end


        def self.process(options={})
          extend Middleman

          mm = ::Middleman::Application.server.inst do
            ENV['REV'] = options['environment']
            config[:environment] = :build
          end

          username = mm.data.credentials.ftp.username
          password = mm.data.credentials.ftp.password

          local_assets_dir = mm.config.assets_dir
          remote_dir = mm.config.ftp_path.split('/')
          ftp = Net::FTP.new('aldo.upload.akamai.com')
          ftp.login(username, password)
          ftp.passive = true
          ftp

          remote_dir = remote_dir.reject { |fn| fn == '' }
          remote_dir.each do |dir|
            begin
              ftp.chdir(dir)
              puts "Switched to #{dir}"
            rescue Exception => exception
              self.handle_dir_exception(exception, ftp, dir)
            end
          end

          begin
            ftp.chdir('assets')
            puts 'Switched to assets'
          rescue Exception => exception
            self.handle_dir_exception(exception, ftp, 'assets')
          end

          Dir.chdir(local_assets_dir) do
            self.filtered_files.each do |filename|
              if File.directory?(filename)
                self.upload_directory(ftp, filename)
              else
                self.upload_binary(ftp, filename)
              end
            end
          end
        end

        def self.handle_dir_exception(exception, ftp, dirname)
          reply     = exception.message
          err_code  = reply[0,3].to_i
          if err_code == 550
            ftp.mkdir(dirname)
            puts "Created #{dirname} directory"
            ftp.chdir(dirname)
          end
        end

        def self.handle_exception(exception, ftp, filename)
          reply     = exception.message
          err_code  = reply[0,3].to_i

          if err_code == 550
            if File.binary?(filename)
              ftp.putbinaryfile(filename, filename)
            else
              ftp.puttextfile(filename, filename)
            end
          end
        end

        def self.upload_binary(ftp, filename)
          begin
            ftp.putbinaryfile(filename, filename)
          rescue Exception => exception
            self.handle_exception(exception, ftp, filename)
          end

          puts "Copied #{filename}"
        end

        def self.upload_directory(ftp, filename)
          begin
            ftp.mkdir(filename)
            puts "Created directory #{filename}"
          rescue
          end
        end

      end
    end
  end
end
