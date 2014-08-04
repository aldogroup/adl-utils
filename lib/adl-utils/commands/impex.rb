require 'middleman-core/cli'
require 'thor'
require 'pry'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli

    class Init
      no_commands do
        def upcase_strip(content)
          regex = /[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/
          content.upcase.gsub(/#{regex}/, '')
        end
        def project_config
          extend Middleman

          mm = ::Middleman::Application.server.inst do
            config[:environment] = :build
          end
          config = {
            season: mm.config.season,
            campaign: mm.config.campaign,
            week: upcase_strip(mm.config.campaign),
            previous_campaign: upcase_strip(mm.config.previous_campaign),
            campaign_start: mm.config.campaign_start,
            special_event: mm.config.special_event
          }
        end
      end
    end

    class Impex < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :impex

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc 'impex', Middleman::ADLUTILS::IMPEX_DESC

      def impex
        build_before
        mm_config = Init.new.project_config
        binding.pry
        generate(mm_config)
      end

      protected

      def impex_yml_file
        "#{File.join(File.dirname(__FILE__), 'impex/data/')}impex_data.yml"
      end

      def impexer_config
        {
          revision: ENV['REV'],
          locales: %w(ca_en ca_fr uk_en_UK us_en_US),
          source_root: File.dirname(__FILE__),
          usage_path: File.join(File.dirname(__FILE__), 'impex/data/'),
          impex_data_file: impex_yml_file,
          impex_data: File.read(impex_yml_file),
          impex_pages: YAML.load(File.read(impex_yml_file))
        }
      end

      def generate(mm_config={})
        generate_config(mm_config)
        impexer_config[:locales].each do |loc|
          generate_content(mm_config, impexer_config, loc)
        end
      end

      def build_before
        if yes?('== Do you want to build your project first ?')
          run("VER=hybris REV=#{ENV['REV']} middleman build --clean") || exit(1)
        end
      end


      def impexify_content(content)
        content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
        content.force_encoding('ASCII-8BIT')
      end

      def generate_content(mm_config={}, impexer_config={}, locale)

        impex_content_file = "build/impex/#{ENV['REV']}/#{mm_config[:season]}-#{mm_config[:campaign]}_#{locale}-#{Time.now.strftime('%y%m%d-%H%M')}.impex"
        create_file impex_content_file, verbose: false


        # =>  Setup the working directory
        build_dir = Pathname.new("build/#{impexer_config[:revision]}/hybris/" + locale)

        # =>  Setup locale & country_code for impex file generation
        mm_campaign_start = mm_config[:campaign_start]

        if locale == 'ca_en' || locale == 'ca_fr'
          country_code = 'ca'
          date_hour = "#{mm_campaign_start['ca'][0]} #{mm_campaign_start['ca'][1]}"
          campaign_start = DateTime.parse(date_hour).strftime('%d.%m.%Y %H:%M:%S')
          (locale == 'ca_en') ? lang = 'en' : lang = 'fr'
        end

        if locale == 'uk_en_UK'
          lang = 'en_UK'
          country_code = 'uk'
          date_hour = "#{mm_campaign_start['uk'][0]} #{mm_campaign_start['uk'][1]}"
          campaign_start = DateTime.parse(date_hour).strftime('%d.%m.%Y %H:%M:%S')
        end

        if locale == 'us_en_US'
          lang = 'en_US'
          country_code = 'us'
          date_hour = "#{mm_campaign_start['us'][0]} #{mm_campaign_start['us'][1]}"
          campaign_start = DateTime.parse(date_hour).strftime('%d.%m.%Y %H:%M:%S')
        end

        # =>  Create an array with all the directories inside the working dir
        @content_dir = Dir.glob('*')

        say("\n\n Generating impex content files for #{locale}", :blue)

        ########################
        #### Hybris ImpEx Header
        ########################
        hybris_header = []
        hybris_header << '#Hybris Header'
        hybris_header << '$contentCatalog=aldoCommerceContentCatalog'
        hybris_header << '$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]'
        hybris_header << '$picture=media(code, $contentCV);'
        hybris_header << '$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog'
        hybris_header << "$lang=#{lang}"
        hybris_header << "$countryCode=#{country_code}$siteResource_content=$countryCode!!$lang!!jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n\n"

        append_to_file impex_content_file, verbose: false do
          hybris_header.join("\n")
        end
        ###############################
        #### End Of Hybris ImpEx Header
        ###############################

        ##############################
        #### Start Of Time Restriction
        ##############################

        campaign_end = (DateTime.parse(campaign_start).end_of_next_month + 1).strftime('%d.%m.%Y %H:%M:%S')
        previous_campaign_start = (DateTime.parse(campaign_start) - 10).strftime('%d.%m.%Y %H:%M:%S')
        previous_campaign_end = (DateTime.parse(campaign_start) - ((0.01 / 24)/36)).strftime('%d.%m.%Y %H:%M:%S')

        # Read page and get content
        impexer_config[:impex_pages].each do |impex_page|

          content = File.join(build_dir, impex_page['page_file'])
          content_page = impexify_content(File.read(content))

          if content.include?('ca_en')
            content_fr = content.gsub('ca_en', 'ca_fr')
            content_fr_page = impexify_content(File.read(content_fr))
          end

          if content.include?('ca_fr')
            content_en = content.gsub('ca_fr', 'ca_en')
            content_en_page = impexify_content(File.read(content_en))
          end

          # Generate the rest of the content
          if !content.include?('ca_en') || !content.include?('ca_fr')
            append_to_file impex_content_file, verbose: false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]\n\n"
            end
          end

          if content.include?('ca_en')
            append_to_file impex_content_file, verbose: false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]\n\n"
            end
          end

          if impex_page['type'] == 'LANDING_PAGE'
            apply_restriction_config = "\n\n#In this section you are tying your time restricted content to a category id. You can also put in a current (not time restricted) landing page or banner\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)\n\n"

            append_to_file impex_content_file, verbose: false do
              apply_restriction_config
            end

            insert_into_file impex_content_file, :before => apply_restriction_config, verbose: false do
              "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{campaign_start};#{campaign_end};\"#{content_page}\"\n"
            end unless locale == 'ca_en' || locale == 'ca_fr'

            if content.include?('ca_en')
              insert_into_file impex_content_file, :before => apply_restriction_config, verbose: false do
                "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{campaign_start};#{campaign_end};\"#{content_page}\";\"#{content_fr_page}\"\n"
              end
            end

            insert_into_file impex_content_file, :after => apply_restriction_config, verbose: false do
              "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";"";"";#{impex_page['page_title']}#{mm_config[:previous_campaign]},#{impex_page['page_title']}#{mm_config[:week]};\n"
            end

            if impex_page.include?('sub_pages')
              if File.exist?(File.join(build_dir.to_s, impex_page['sub_pages'][0]['page_file']))
                impex_page['sub_pages'].each do |sub_page|
                  sub_content = File.join(build_dir, sub_page['page_file'])
                  sub_content_page = impexify_content(File.read(sub_content)) unless File.file?(sub_content)

                  previous_sublp = "##{sub_page['page_title']}\n;#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:previous_campaign]};<ignore>;;#{sub_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n"
                  current_sublp = ";#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};<ignore>;;#{sub_page['type']};#{campaign_start};#{campaign_end};\"#{sub_content_page}\"\n"

                  insert_into_file impex_content_file, :before => apply_restriction_config, verbose: false do
                    "#{previous_sublp}#{current_sublp}"
                  end

                  insert_into_file impex_content_file, :after => apply_restriction_config, verbose: false do
                    "##{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";" ";" ";#{impex_page['page_title']}#{mm_config[:previous_campaign]},#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};\n"
                  end

                end # End of sub_pages generator loop
              else
                # binding.pry
                say("\s\sError: #{File.join(build_dir, impex_page['sub_pages'][0]['page_file'])} Not found", :red)
                say("\s\s Ignoring #{impex_page['sub_pages'][0]['page_title']}, because the file is missing.\n\n", :magenta)
              end
            end # End of sub_pages conditional check
          end

        end # End of impex_pages loop

      end # End of the generate method

      def print_usage_and_die(message)
        usage_path    = File.join(File.dirname(__FILE__), '..', '..', 'USAGE')
        usage_message = File.read(usage_path)

        raise Error, "ERROR: #{message}\n#{usage_message}"
      end
    end
  end
end
