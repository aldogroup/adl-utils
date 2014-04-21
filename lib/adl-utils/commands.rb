require "middleman-core/cli"
require 'god'
require 'adl-utils/methods/git'
require 'adl-utils/strategies'
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
        impex_data = File.read('data/impex_data.yml')
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
          # Generate the rest of the content
          append_to_file impex_file, :verbose => false do
            "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n"
          end
          if impex_page['type'] == 'landing page'
            append_to_file(impex_file, "##{impex_page['page_title']}\n;;#{impex_page['hybris_id']};\"#{content_page}\";\"\";\n", :verbose => false)
          end
          if impex_page['type'] == 'category banner'
            append_to_file(impex_file, "##{impex_page['page_title']}\n;;#{impex_page['hybris_id']};;\"#{content_page}\"\n", :verbose => false)
          end

          if impex_page.include?("sub_pages")

            impex_page['sub_pages'].each do |sub_page|
              sub_content = File.join(build_dir, sub_page['page_file'])
              sub_content_page = File.read(sub_content).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
              say("Reading & Generating #{impex_page['page_title']} #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)

              if sub_page['type'] == 'landing page'
                say("Reading & Generating #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)
                append_to_file(impex_file, "##{impex_page['page_title']} #{sub_page['page_title']}\n;;#{sub_page['hybris_id']};\"#{sub_content_page}\";\"\";\n", :verbose => false)
              elsif sub_page['type'] == 'category banner'
                append_to_file(impex_file, "##{impex_page['page_title']} #{sub_page['page_title']}\n;;#{sub_page['hybris_id']};;\"#{sub_content_page}\"\n", :verbose => false)
              else
                append_to_file(impex_file, "##{impex_page['page_title']} #{sub_page['page_title']}\n;;#{sub_page['hybris_id']};\"#{sub_content_page}\"\n", :verbose => false)
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
            append_to_file(impex_file, "##{l3_hybris_page_name}\n;;#{l3_hybris_id};;\"#{l3_content_page}\"\n", :verbose => false)
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
        # run("git tag v#{release_version} -m #{description}")
        # run('git push origin master')
        run("git push origin v#{release_version}")
        # server_instance   = ::Middleman::Application.server.inst
        #
        # camelized_method  = self.deploy_options.method.to_s.split('_').map { |word| word.capitalize}.join
        # method_class_name = "Middleman::ADLUTILS::Methods::#{camelized_method}"
        # method_instance   = method_class_name.constantize.new(server_instance, self.deploy_options)
        #
        # method_instance.process
      end

    end

    # class Daemon < Thor < God
    #   include Thor::Actions
    #   include God::CLI
    #
    #   check_unknown_options!
    #
    #   namespace :daemon
    #
    #   def self.exit_on_failure?
    #     true
    #   end
    #
    #   desc "daemon [options]", Middleman::ADLUTILS::DAEMON_DESC
    #   method_option 'port',
    #     :aliases => '-p',
    #     :type => :numeric,
    #     :default => 1337,
    #     :desc => 'Set a custom port'
    #   method_option 'stop',
    #     :type => :boolean,
    #     :default => false,
    #     :desc => "stop the daemon"
    #   method_option 'restart',
    #     :type => :boolean,
    #     :default => false,
    #     :desc => "restart the daemon"
    #   def daemon
    #     if options['stop']
    #       stop
    #     end
    #     if options['restart']
    #       restart
    #     end
    #     god run_as_daemon(options)
    #   end
    #
    #   # def stop
    #   #   stop_daemon
    #   # end
    #   # desc "daemon restart",
    #   # def restart
    #   #   restart_daemon
    #   # end
    #
    #   protected
    #
    #   def run_as_daemon(options={})
    #     port = options['port']
    #     project_root = ENV['MM_ROOT']
    #     God.pid_file_directory = project_root + "/.god"
    #
    #     %w{4567}.each do |port|
    #       God.watch do |w|
    #         w.dir = project_root
    #         w.log = project_root + "/.god/middleman.log"
    #         w.name = "middleman"
    #
    #         w.interval = 30.seconds
    #
    #         w.start = "middleman server --port=#{port} --verbose"
    #         w.stop = "killall -9 middleman"
    #         w.restart = "killall -9 middleman | middleman server --port=#{port} --verbose"
    #
    #         w.behavior(:clean_pid_file)
    #
    #         w.start_if do |start|
    #           start.condition(:process_running) do |c|
    #             c.interval = 5.seconds
    #             c.running = false
    #           end
    #         end
    #
    #         w.restart_if do |restart|
    #           restart.condition(:memory_usage) do |c|
    #             c.above = 150.megabytes
    #             c.times = [3, 5] # 3 out of 5 intervals
    #           end
    #
    #           restart.condition(:cpu_usage) do |c|
    #             c.above = 50.percent
    #             c.times = 5
    #           end
    #         end
    #
    #         # lifecycle
    #         w.lifecycle do |on|
    #           on.condition(:flapping) do |c|
    #             c.to_state = [:start, :restart]
    #             c.times = 5
    #             c.within = 5.minute
    #             c.transition = :unmonitored
    #             c.retry_in = 10.minutes
    #             c.retry_times = 5
    #             c.retry_within = 2.hours
    #           end
    #         end
    #       end
    #     end
    #   end
    #   def stop_daemon
    #   end
    #   def restart_daemon
    #   end
    # end

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

      def restructure(options={})
        puts "== Rebuilding"
        # Set variables
        revision = options['environment']
        version = options['platform']
        source_root = ENV['MM_ROOT']
        Dir.chdir(source_root)
        build_folder  = "build"
        build_dir = Pathname.new(build_folder + "/#{revision}/#{version}")
        if version == 'icongo'
          locale_list   = %w(ca-eng ca-fre us uk)
        else
          locale_list = %w(ca_en ca_fr us_en_US uk_en_UK)
        end

        # Check to see if the build folder exists, kill if it doesn't
        unless File.directory?(build_folder)
          puts set_color "== The build folder does not exist", :red
          return
        end

        # Change to build > revision > version directory
        Dir.chdir(build_dir)

        # Grab the list of directories depending on the revision
        # and version that was passed to this method, remove assets folder
        directory_list = Dir.glob("**").select { |fn| File.directory?(fn) }

        # Delete the sitemap file
        if File.exists?('index.html')
          File.delete('index.html')
        end

        # Loop through all locales folders
        directory_list.each do |folder|

          # Check to see if there are any folders that
          # don't match locales and skip them if so
          unless locale_list.include?(folder)
            puts "== Skipping the '#{folder}' folder"
            next
          end

          # Switch into the current locale directory
          Dir.chdir(folder)

          page_folders = Dir.glob("**/*/").select { |fn| File.directory?(fn) }

          # Loop over each page folder
          page_folders.each do |page|

            # Search for the index.html file
            Dir.glob(page + "/*.html").each do |f|
              if [".", ".."].include?(f)
                next
              end

              # Rename the file into current locale directory
              File.rename(f, page + File.extname(f))
            end

            # Delete page folder
            FileUtils.rm_rf page

          end

          # Go back to list of locales
          Dir.chdir("..")

        end

        puts "== Done"
      end
    end

  end
end
