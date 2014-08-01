require "middleman-core/cli"
require 'pry'
# require 'awesome_print'
# require 'adl-utils/methods/git'
# require 'adl-utils/strategies'
require 'adl-utils/version'
require 'expanded_date'
require 'adl-utils/commands/impex'

module Middleman
  module Cli
    # This class provides a "deploy" command for the middleman CLI.

    class Release < Thor
        include Thor::Actions

        check_unknown_options!

        namespace :release

        # Tell Thor to exit with a nonzero exit code on failure
        def self.exit_on_failure?
            true
        end

        desc 'release [options]', Middleman::ADLUTILS::RELEASE_DESC
        method_option 'build_before',
            :type     => :boolean,
            :aliases  => '-b',
            :desc     => 'Run \'middleman build\' before creating the release'
        method_option 'environment',
            :default => 'dev',
            :aliases => '-e',
            :type     => :string,
            :desc     => 'Specify environment for the release(Default: dev)'
        method_option 'platform',
            :aliases => '-p',
            :default => 'icongo',
            :type => :string,
            :desc => 'version (icongo or hybris)'
        def release
            build_before(options)
            process
        end

        protected

        def build_before(options={})
            build_enabled = options['build_before']
            if build_enabled
                # http://forum.middlemanapp.com/t/problem-with-the-build-task-in-an-extension
                revision = options['environment']
                version = options['platform']
                run("VER=#{version} REV=#{revision} middleman build --clean", {:verbose => false}) || exit(1)
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
            description = description_raw.gsub(/\n/,'"\0"')
            run(`git tag -a v#{release_version} -m "#{description}"`)
            run("git push origin v#{release_version}")
        end

    end

    class Daemon < Thor
        include Thor::Actions

        check_unknown_options!

        namespace :daemon

        def self.exit_on_failure?
            true
        end

        desc 'daemon [options]', Middleman::ADLUTILS::DAEMON_DESC
        method_option 'start',
            :type => :boolean,
            :default => false,
            :desc => 'Start middleman as daemon'
        method_option 'stop',
            :type => :boolean,
            :default => false,
            :desc => 'stop the daemon'
        method_option 'restart',
            :type => :boolean,
            :default => false,
            :desc => 'restart the daemon'
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
            run("god start middleman -c #{godfile_template}", {:verbose => false}) || exit(1)
            puts set_color '== Middleman Server is running at: http://localhost:1337/', :green
        end

        def stop_daemon
            run("god stop middleman -c #{godfile_template}", {:verbose => false}) || exit(1)
        end

        def restart_daemon
            run("god restart middleman -c #{godfile_template}", {:verbose => false}) || exit(1)
        end
    end

    class Rebuild < Thor
        include Thor::Actions

        check_unknown_options!

        namespace :rebuild

        # Tell Thor to exit with a nonzero exit code on failure
        def self.exit_on_failure?
            true
        end

        desc 'rebuild [options]', Middleman::ADLUTILS::REBUILD_DESC
        method_option 'environment',
            :aliases => '-e',
            :default => 'dev',
            :type => :string,
            :desc => 'Call rebuild task'
        method_option 'platform',
            :aliases => '-p',
            :default => 'icongo',
            :type => :string,
            :desc => 'version (icongo or hybris)'

        def rebuild
            build(options)
            restructure(options)
        end

        protected

        def build(options={})

            if yes?('== Do you want to build your project first ?')
                revision = options['environment']
                version = options['platform']
                run("VER=#{version} REV=#{revision} middleman build --clean", {:verbose => false}) || exit(1)
            end

        end

        source_root ENV['MM_ROOT']

        def restructure(options={})
            puts "== Rebuilding"
            revision = options['environment']
            version = options['platform']
            # Set variables
            source_root = ENV['MM_ROOT']
            build_folder  = 'build'
            work_folder = 'rebuild'
            locale_list   = %w(ca-eng ca-fre us uk)

            # Check to see if the build folder exists, kill if it doesn't
            unless File.directory?(build_folder)
                puts set_color '== The build folder does not exist', :red
                return
            end

            if Dir.exist?(work_folder)
                FileUtils.rm_rf work_folder
                directory(build_folder + "/#{revision}/#{version}", work_folder, {:verbose => false})
            else
                directory(build_folder + "/#{revision}/#{version}", work_folder, {:verbose => false})
            end
            # Change to build > revision > version directory
            Dir.chdir(work_folder)
            # Grab the list of directories depending on the revision
            # and version that was passed to this method, remove assets folder
            directory_list = Dir.glob('*').select { |fn| File.directory?(fn) }
            directory_list = directory_list.reject { |fn| fn == 'assets' }

            # Delete the sitemap file
            if File.exists?('index.html')
                File.delete('index.html')
            end

            # Loop through all locales folders
            directory_list.each do |folder|

                # Switch into the current locale directory
                locale_folder = File.join(source_root, work_folder + '/' + folder)
                Dir.chdir(locale_folder)
                homepage_file = File.join(Dir.getwd, Dir.glob('*.html'))
                copy_file homepage_file, work_folder + '/homepage_' + folder + '.html'
                page_folders = Dir.glob('*').select { |fn| File.directory?(fn) }
                # Loop over each page folder
                page_folders.each do |page|

                    # Search for the index.html file
                    page_folder = File.join(locale_folder,page)
                    Dir.chdir(page_folder)
                    Dir.glob('*').each do |f|
                        if ['.', '..'].include?(f)
                            next
                        end
                        current_dir = Dir.glob('*')
                        if current_dir.length > 1
                            current_dir.each do |sf|
                                if File.extname(sf) == '.html'
                                    new_filename = work_folder + '/' + page + '_' + folder + '.html'
                                    sf = work_folder + '/' + folder + '/' + sf
                                    copy_file sf, new_filename
                                else
                                    Dir.chdir(File.join(page_folder, sf))
                                    current_file = File.join(Dir.getwd, Dir.glob('*'))
                                    new_filename = work_folder + '/' + page + '-' + sf + '_' + folder  + '.html'
                                    copy_file current_file, new_filename
                                end
                            end
                        else
                            current_file = File.join(Dir.getwd, Dir.glob('*'))
                            new_filename = work_folder + '/' + page + '_' + folder + '.html'
                            copy_file current_file, new_filename
                        end

                    end

                end

                # Go back to list of locales
                Dir.chdir('..')

            end

            #Cleanup folders
            Dir.chdir(File.join(source_root, work_folder))
            directory_list.each do |rfolder|
                trash_folder = File.join(source_root, work_folder + '/' + rfolder)
                remove_dir trash_folder
            end

            puts '== Done'
        end
    end

    class Akamai_Sync < Thor
        include Thor::Actions

        check_unknown_options!

        namespace :akamai_sync

        # Tell Thor to exit with a nonzero exit code on failure
        def self.exit_on_failure?
            true
        end

        desc 'akamai_sync [options]', Middleman::ADLUTILS::AKAMAI_DESC
        method_option 'build_before',
            :type     => :boolean,
            :aliases  => "-b",
            :desc     => 'Run `middleman build` before creating the release'
        method_option 'environment',
            :default => 'dev',
            :aliases => '-e',
            :type     => :string,
            :desc => 'Specify environment for the release(Default: dev)'
        method_option 'platform',
            :aliases => '-p',
            :default => 'icongo',
            :type => :string,
            :desc => 'version (icongo or hybris)'
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
