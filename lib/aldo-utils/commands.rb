require "middleman-core/cli"

# require "middleman-deploy/extension"
require 'aldo-utils/methods/git'
require 'aldo-utils/strategies'
require 'aldo-utils/version'

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

      desc "impex [options]", Middleman::ALDOUTILS::IMPEX_DESC
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
          "#Hybris Header\n$contentCatalog=aldoCommerceContentCatalog
    $contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]
    $picture=media(code, $contentCV);
    $siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog
    $lang=#{lang}
    $countryCode=#{country_code}
    $siteResource_content=$countryCode!!$lang!!jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n"
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
            "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog
    $catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]
    UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n"
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
        method_class_name = "Middleman::ALDOUTILS::Methods::#{camelized_method}"
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

      desc "release [options]", Middleman::ALDOUTILS::RELEASE_DESC
      method_option "build_before",
        :type     => :boolean,
        :aliases  => "-b",
        :desc     => "Run `middleman build` before generating impex files"
      def deploy
        build_before(options)
        process
      end

      protected

      def build_before(options={})
        build_enabled = options.fetch('build_before', self.deploy_options.build_before)

        if build_enabled
          # http://forum.middlemanapp.com/t/problem-with-the-build-task-in-an-extension
          run('middleman build') || exit(1)
        end
      end

      def release
      end

      def print_usage_and_die(message)
        usage_path    = File.join(File.dirname(__FILE__), '..', '..', 'USAGE')
        usage_message = File.read(usage_path)

        raise Error, "ERROR: #{message}\n#{usage_message}"
      end

      def process
        server_instance   = ::Middleman::Application.server.inst

        camelized_method  = self.deploy_options.method.to_s.split('_').map { |word| word.capitalize}.join
        method_class_name = "Middleman::ALDOUTILS::Methods::#{camelized_method}"
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

  end
end
