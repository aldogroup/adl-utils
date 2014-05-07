require "middleman-core/cli"
require 'pry'
# require 'adl-utils/methods/git'
# require 'adl-utils/strategies'
require 'adl-utils/version'

module Middleman
  module Cli
    # This class provides a "deploy" command for the middleman CLI.
    class Impex < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :impex

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc "impex [options]", Middleman::ADLUTILS::IMPEX_DESC
      method_option "build_before",
        :type     => :boolean,
        :aliases  => "-b",
        :desc     => "Run `middleman build` before generating impex files"
      method_option 'environment',
        :default => 'dev',
        :aliases => '-e',
        :type     => :string,
        :desc     => "Specify environment for generating impex files(Default: dev)"
      def impex
        build_before(options)
        generate(options)
      end

      protected

      def generate(options={})
        revision = options['environment']
        all_locale = %w(ca_en ca_fr uk_en_UK us_en_US)
        source_root = File.dirname(__FILE__)
        usage_path = File.join(File.dirname(__FILE__), '/data/')
        impex_data_file = usage_path + 'impex_data.yml'
        impex_data = File.read(impex_data_file)
        impex_pages = YAML.load(impex_data)
        all_locale.each do |loc|
          generate_with_locale(source_root,loc,impex_pages,revision)
        end
      end

      def build_before(options={})
        build_enabled = options['build_before']
        if build_enabled
          # http://forum.middlemanapp.com/t/problem-with-the-build-task-in-an-extension
          run("VER=hybris REV=#{options['environment']} middleman build --clean") || exit(1)
        end
      end

      def generate_with_locale(source_root,locale,impex_pages,revision)
        # Dir.chdir(ENV['MM_ROOT'])
        FileUtils.rm("build/impex/#{locale}.impex") if options[:force]
        create_file "build/impex/#{locale}.impex", :verbose => false
        impex_file = "build/impex/#{locale}.impex"

        # =>  Setup the working directory
        build_dir = Pathname.new("build/#{revision}/hybris/" + locale)

        # =>  Setup locale & country_code for impex file generation
        if locale == 'ca_en' || locale == 'ca_fr'
          country_code = 'ca'
          if locale == 'ca_en'
            lang = 'en'
          else
            lang = 'fr'
          end
        end
        if locale == 'uk_en_UK'
          lang = 'en_UK'
          country_code = 'uk'
        end
        if locale == 'us_en_US'
          lang = 'en_US'
          country_code = 'us'
        end

        # =>  Create an array with all the directories inside the working dir
        content_dir = Dir.glob('*')

        say("== Generating impex files for #{locale}", :green)

        append_to_file impex_file, :verbose => false do
          "#Hybris Header\n$contentCatalog=aldoCommerceContentCatalog\n$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]\n$picture=media(code, $contentCV);\n$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n$lang=#{lang}\n$countryCode=#{country_code}\n$siteResource_content=$countryCode!!$lang!!jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n"
        end

        # =>  Read page and get content
        impex_pages.each do |impex_page|
          content = File.join(build_dir, impex_page['page_file'])
          content_page = File.read(content).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
          say("Reading & Generating #{impex_page['page_title']} using #{impex_page['type']} template...", :yellow)
          if impex_page['page_title'] == 'homepage'
            append_to_file impex_file, :verbose => false do
              "\n# Homepage \nINSERT_UPDATE CMSParagraphComponent;$contentCV[unique=true];uid[unique=true];content[lang=$lang]\n;;#{impex_page['hybris_id']};\"#{content_page}\"\n"
            end
          end

          head_content_path = File.join(build_dir, '/head.html')
          head_content = File.read(head_content_path).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
          say("Generating head template...", :yellow)
          append_to_file impex_file, :verbose => false do
            "\n# Header Component\n;;HTMLHeaderComponent;\"#{head_content}\"\n"
          end
          footer_content_path = File.join(build_dir, '/footer.html')
          footer_content = File.read(footer_content_path).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
          say("Generating footer template...", :yellow)
          append_to_file impex_file, :verbose => false do
            "\n# Footer Component\n;;HTMLFooterComponent;\"#{footer_content}\"\n"
          end

          # Generate the rest of the content
          append_to_file impex_file, :verbose => false do
            "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog
    $catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]
    UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n"
          end
          if impex_page['type'] == 'landing page'
            append_to_file(impex_file, "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";\"#{content_page}\";\"\";\n", :verbose => false)
          end
          if impex_page['type'] == 'category banner'
            append_to_file(impex_file, "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";;\"#{content_page}\"\n", :verbose => false)
          end

          if impex_page.include?("sub_pages")

            impex_page['sub_pages'].each do |sub_page|
              sub_content = File.join(build_dir, sub_page['page_file'])
              sub_content_page = File.read(sub_content).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
              say("Reading & Generating #{impex_page['page_title']} #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)

              if sub_page['type'] == 'landing page'
                say("Reading & Generating #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)
                append_to_file(impex_file, "##{impex_page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\"#{sub_content_page}\";\"\";\n", :verbose => false)
              elsif sub_page['type'] == 'category banner'
                append_to_file(impex_file, "##{impex_page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";;\"#{sub_content_page}\"\n", :verbose => false)
              else
                append_to_file(impex_file, "##{impex_page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\"#{sub_content_page}\"\n", :verbose => false)
              end # End of check for page type inside sub_pages

            end # End of sub_pages generator loop

          end # End of sub_pages conditional check

        end # End of impex_pages loop


        # =>  Setup the working directory
        l3_build_dir = build_dir + '/l3'
        # =>  Create an array with all the directories inside the working dir
        l3_content_dir = Dir.glob(build_dir + 'l3/*')
        say("Generating L3 for #{locale}...", :yellow)
        append_to_file(impex_file, "\n#L3 Content Page\n", :verbose => false)
        l3_content_dir.each do |l3_content|
          l3_hybris_page_name = l3_content.to_s.gsub(/\d{3,}-/, '').gsub(/\-/,' ').strip
          l3_hybris_id = l3_content.match(/\d{3,}/).to_s
          unless l3_hybris_id.empty?
            l3_content_page = File.read("#{l3_content}/index.html").gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
            append_to_file(impex_file, "##{l3_hybris_page_name}\n;;\"#{l3_hybris_id}\";;\"#{l3_content_page}\"\n", :verbose => false)
          end
        end
        say("Finished to generate the impex file for #{locale}\nYou can find it in: #{impex_file}")

      end # End of the generate method

      def print_usage_and_die(message)
        usage_path    = File.join(File.dirname(__FILE__), '..', '..', 'USAGE')
        usage_message = File.read(usage_path)

        raise Error, "ERROR: #{message}\n#{usage_message}"
      end

      def process
        server_instance   = ::Middleman::Application.server.inst

        camelized_method  = self.deploy_options.method.to_s.split('_').map { |word| word.capitalize}.join
        method_class_name = "Middleman::ADLUTILS::Methods::#{camelized_method}"
        method_instance   = method_class_name.constantize.new(server_instance, self.deploy_options)

        method_instance.process
      end

      def deploy_options
        options = nil

        begin
          options = ::Middleman::Application.server.inst.options
        rescue NoMethodError
          print_usage_and_die "You need to activate the deploy extension in config.rb."
        end

        unless options.method
          print_usage_and_die "The deploy extension requires you to set a method."
        end
        options
      end
    end

    class Release < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :release

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc "release [options]", Middleman::ADLUTILS::RELEASE_DESC
      method_option "build_before",
          :type     => :boolean,
          :aliases  => "-b",
          :desc     => "Run `middleman build` before creating the release"
        method_option 'environment',
          :default => 'dev',
          :aliases => '-e',
          :type     => :string,
          :desc     => "Specify environment for the release(Default: dev)"
        method_option 'platform',
          :aliases => "-p",
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
        release_version = ask("Specify a release version (needs to be formated like vx.x.x where x is a numeric value): ")
        description_raw = ask("Please type a description: ")
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

      desc "daemon [options]", Middleman::ADLUTILS::DAEMON_DESC
      method_option 'start',
        :type => :boolean,
        :default => false,
        :desc => 'Start middleman as daemon'
      method_option 'stop',
        :type => :boolean,
        :default => false,
        :desc => "stop the daemon"
      method_option 'restart',
        :type => :boolean,
        :default => false,
        :desc => "restart the daemon"
      def daemon
        if options['stop']
          stop_daemon
        elsif options['restart']
          restart_daemon
        elsif options['start']
          start_daemon
        else
          puts set_color "== You need to specify an option to run middleman as daemon.\nPlease use: middleman daemon --help", :red
        end
      end

      protected

      def start_daemon
        usage_path = File.join(File.dirname(__FILE__), '/data/')
        godfile_template = usage_path + 'middleman.god'
        puts set_color "== Starting Middleman with icongo settings using dev environment", :yellow
        run("god start middleman -c #{godfile_template}", {:verbose => false}) || exit(1)
        puts set_color "== Middleman Server is running at: http://localhost:1337/", :green
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

      desc "rebuild [options]", Middleman::ADLUTILS::REBUILD_DESC
      method_option 'environment',
        :aliases => "-e",
        :default => 'dev',
        :type => :string,
        :desc => "Call rebuild task"
      method_option 'platform',
        :aliases => "-p",
        :default => 'icongo',
        :type => :string,
        :desc => 'version (icongo or hybris)'

      def rebuild
        build(options)
        restructure(options)
      end

      protected

      def build(options={})

        if yes?("== Do you want to build your project first ?")
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
        build_folder  = "build"
        work_folder = 'rebuild'
        locale_list   = %w(ca-eng ca-fre us uk)

        # Check to see if the build folder exists, kill if it doesn't
        unless File.directory?(build_folder)
          puts set_color "== The build folder does not exist", :red
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
        directory_list = Dir.glob("*").select { |fn| File.directory?(fn) }
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
          page_folders = Dir.glob("*").select { |fn| File.directory?(fn) }
          # Loop over each page folder
          page_folders.each do |page|

            # Search for the index.html file
            page_folder = File.join(locale_folder,page)
            Dir.chdir(page_folder)
            Dir.glob("*").each do |f|
              if [".", ".."].include?(f)
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
          Dir.chdir("..")

        end

        #Cleanup folders
        Dir.chdir(File.join(source_root, work_folder))
        directory_list.each do |rfolder|
          trash_folder = File.join(source_root, work_folder + '/' + rfolder)
          remove_dir trash_folder
        end

        puts "== Done"
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

      desc "akamai_sync [options]", Middleman::ADLUTILS::AKAMAI_DESC
      method_option "build_before",
          :type     => :boolean,
          :aliases  => "-b",
          :desc     => "Run `middleman build` before creating the release"
        method_option 'environment',
          :default => 'dev',
          :aliases => '-e',
          :type     => :string,
          :desc     => "Specify environment for the release(Default: dev)"
        method_option 'platform',
          :aliases => "-p",
          :default => 'icongo',
          :type => :string,
          :desc => 'version (icongo or hybris)'
      def akamai_sync
        build_before(options)
        FtpConfig.process(options)
      end

      protected

      def build_before(options={})
        if yes?("== Do you want to build your project first ?")
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
          remote_dir = mm.config.ftp_path.split("/")
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
            puts "Switched to assets"
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
