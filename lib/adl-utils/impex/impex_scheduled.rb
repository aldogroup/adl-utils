require 'adl-utils/version'
require 'expanded_date'

module Middleman
  class ScheduledImpexExtension < Cli:Impex

    def initialize(app, options_hash={}, &block)
      super
    end

    include Thor::Actions

    check_unknown_options!

    namespace :impex

    # Tell Thor to exit with a nonzero exit code on failure
    def self.exit_on_failure?
      true
    end

    desc "impex", Middleman::ADLUTILS::IMPEX_DESC

    def impex_scheduled
      build_before()
      mm_var()
    end

    protected

    def mm_var
      extend Middleman

      mm = ::Middleman::Application.server.inst do
        config[:environment] = :build
      end

      mm_config = {
        'season' => mm.config.season,
        'campaign' => mm.config.campaign,
        'week' => mm.config.campaign.upcase.gsub(/[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/,''),
        'previous_campaign' => mm.config.previous_campaign.upcase.gsub(/[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/,''),
        'campaign_start' => mm.config.campaign_start,
        'special_event' => mm.config.special_event
      }

      generate(mm_config)
    end

    def generate(mm_config={})
      impexer_config = {
        'revision' => ENV['REV'],
        'locales' => %w(ca_en ca_fr uk_en_UK us_en_US),
        'source_root' => File.dirname(__FILE__),
        'usage_path' => File.join(File.dirname(__FILE__), '/data/'),
        'impex_data_file' => File.join(File.dirname(__FILE__), '/data/') + 'impex_data.yml',
        'impex_data' => File.read(File.join(File.dirname(__FILE__), '/data/') + 'impex_data.yml'),
        'impex_pages' => YAML.load(File.read(File.join(File.dirname(__FILE__), '/data/') + 'impex_data.yml'))
      }

      generate_config(mm_config)
      # binding.pry
      impexer_config['locales'].each do |loc|
        generate_content(mm_config,impexer_config,loc)
      end

    end

    def build_before
      if yes?("== Do you want to build your project first ?")
        # http://forum.middlemanapp.com/t/problem-with-the-build-task-in-an-extension
        run("VER=hybris REV=#{ENV['REV']} middleman build --clean") || exit(1)
      end
    end

    def generate_config(mm_config={})
      create_file "build/impex/#{ENV['REV']}/1-#{mm_config['season']}-#{mm_config['campaign']}_config-#{Time.now.strftime('%y%m%d-%H%M')}.impex", :verbose => false
      impex_config_file = "build/impex/#{ENV['REV']}/1-#{mm_config['season']}-#{mm_config['campaign']}_config-#{Time.now.strftime('%y%m%d-%H%M')}.impex"
      say("\n░▒▓ Starting ImpEx Builder Tool ▓▒░\n", :green)

      append_to_file impex_config_file, :verbose => false do
        "\n####################################################\n#                    WCMS CONFIG                   #\n####################################################\n\n#### DO NOT MODIFY ####\n# Macros / Replacement Parameter definitions\n$contentCatalog=aldoCommerceContentCatalog\n$caProductCatalog=caAldoProductCatalog\n$ukProductCatalog=ukAldoProductCatalog\n$usProductCatalog=usAldoProductCatalog\n\n$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]\n$caProductCV=catalogVersion(catalog(id[default=$caProductCatalog]),version[default='Staged'])[unique=true,default=$caProductCatalog:Staged]\n$ukProductCV=catalogVersion(catalog(id[default=$ukProductCatalog]),version[default='Staged'])[unique=true,default=$ukProductCatalog:Staged]\n$usProductCV=catalogVersion(catalog(id[default=$usProductCatalog]),version[default='Staged'])[unique=true,default=$usProductCatalog:Staged]\n$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n\n#### END DO NOT MODIFY ####\n\n#### CREATE COMPONENTS FOR HOME PAGE (header, content & footer) ####\n# CMS Paragraph Components\nINSERT_UPDATE CMSParagraphComponent;$contentCV[unique=true];uid[unique=true];name;&componentRef\n;;HomepageComponent#{mm_config['previous_campaign']};Home Page Component for #{mm_config['previous_campaign']};HomepageComponent#{mm_config['previous_campaign']};\n;;HTMLHeaderComponent#{mm_config['previous_campaign']};HTML Header Component for #{mm_config['previous_campaign']};HTMLHeaderComponent#{mm_config['previous_campaign']};\n;;HTMLFooterComponent#{mm_config['previous_campaign']};HTML Footer Component for #{mm_config['previous_campaign']};HTMLFooterComponent#{mm_config['previous_campaign']};\n;;PermanentFooterComponent; Permanent Footer Component;PermanentFooterComponent;\n\n;;HomepageComponent#{mm_config['week']};Home Page Component for #{mm_config['week']};HomepageComponent#{mm_config['week']};\n;;HTMLHeaderComponent#{mm_config['week']};HTML Header Component for #{mm_config['week']};HTMLHeaderComponent#{mm_config['week']};\n;;HTMLFooterComponent#{mm_config['week']};HTML Footer Component for #{mm_config['week']};HTMLFooterComponent#{mm_config['week']};\n\n\n#### ADD THE ABOVE COMPONENTS TO THE RIGHT HOME PAGE PLACEHOLDERS ####\n# Once you create the new paragraph component above, add it to the component list separated by a comma like I did with MegaPromoBanner2 below\nINSERT_UPDATE ContentSlot;$contentCV[unique=true];uid[unique=true];name;active;cmsComponents(&componentRef)\n;;HTMLHeaderSlot;HTML Header Slot;true;HTMLHeaderComponent#{mm_config['previous_campaign']},HTMLHeaderComponent#{mm_config['week']};\n;;FooterSlot;Footer;true;PermanentFooterComponent,HTMLFooterComponent#{mm_config['previous_campaign']},HTMLFooterComponent#{mm_config['week']};\n;;Section1Slot-Homepage;Section1 Slot for Homepage;true;HomepageComponent#{mm_config['previous_campaign']},HomepageComponent#{mm_config['week']};"
      end

      say("\n☑ Finished generating config file", :green)

    end

    def generate_content(mm_config={},impexer_config={},locale)
      FileUtils.rm("build/impex/#{ENV['REV']}/#{locale}.impex") if options[:force]

      create_file "build/impex/#{ENV['REV']}/#{mm_config['season']}-#{mm_config['campaign']}_#{locale}-#{Time.now.strftime('%y%m%d-%H%M')}.impex", :verbose => false
      impex_content_file = "build/impex/#{ENV['REV']}/#{mm_config['season']}-#{mm_config['campaign']}_#{locale}-#{Time.now.strftime('%y%m%d-%H%M')}.impex"

      # =>  Setup the working directory
      build_dir = Pathname.new("build/#{impexer_config['revision']}/hybris/" + locale)

      # =>  Setup locale & country_code for impex file generation
      mm_campaign_start = mm_config['campaign_start']
      if locale == 'ca_en' || locale == 'ca_fr'
        country_code = 'ca'
        date_hour = "#{mm_campaign_start['ca'][0]} #{mm_campaign_start['ca'][1]}"
        campaign_start = DateTime.parse(date_hour).strftime('%d.%m.%Y %H:%M:%S')
        if locale == 'ca_en'
          lang = 'en'
        else
          lang = 'fr'
        end
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

      say("\n\n✪ Generating impex content files for #{locale}", :blue)

      ########################
      #### Hybris ImpEx Header
      ########################
      append_to_file impex_content_file, :verbose => false do
        "#Hybris Header\n$contentCatalog=aldoCommerceContentCatalog\n$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]\n$picture=media(code, $contentCV);\n$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n$lang=#{lang}\n$countryCode=#{country_code}\n$siteResource_content=$countryCode!!$lang!!jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n"
      end
      ###############################
      #### End Of Hybris ImpEx Header
      ###############################

      ##############################
      #### Start Of Time Restriction
      ##############################
      campaign_end = (DateTime.parse(campaign_start).end_of_next_month + 1).strftime('%d.%m.%Y %H:%M:%S')
      # binding.pry
      previous_campaign_start = (DateTime.parse(campaign_start) - 10).strftime('%d.%m.%Y %H:%M:%S')
      previous_campaign_end = (DateTime.parse(campaign_start) - ((0.01 / 24)/36)).strftime('%d.%m.%Y %H:%M:%S')

      append_to_file impex_content_file, :verbose => false do
        "\n####################################################\n"
      end
      append_to_file impex_content_file, :verbose => false do
        "#                TIME RESTRICTIONS                 #\n"
      end
      append_to_file impex_content_file, :verbose => false do
        "####################################################\n"
      end
      append_to_file impex_content_file, :verbose => false do
        "#Create time restrictions here then add time restriction name to the end of each component\n"
      end
      append_to_file impex_content_file, :verbose => false do
        "INSERT_UPDATE CMSTimeRestriction;$contentCV[unique=true];uid[unique=true];name;activeFrom[dateformat=dd.MM.yyyy HH:mm:ss];activeUntil[dateformat=dd.MM.yyyy HH:mm:ss]\n"
      end
      append_to_file impex_content_file, :verbose => false do
        ";;Time-Restriction-#{mm_config['previous_campaign']};Time Restriction #{mm_config['previous_campaign']};#{previous_campaign_start};#{previous_campaign_end};\n"
      end
      append_to_file impex_content_file, :verbose => false do
        ";;Time-Restriction-#{mm_config['week']};Time Restriction #{mm_config['week']};#{campaign_start};#{campaign_end};\n"
      end

      #### End Of Time Restriction

      # =>  Read page and get content
      impexer_config['impex_pages'].each do |impex_page|

        content = File.join(build_dir, impex_page['page_file'])
        content_page = File.read(content).gsub(' "', '"').gsub('"', '""').gsub(/\n/, '').force_encoding("ASCII-8BIT")

        if content.include?('ca_en')
          content_fr = content.gsub('ca_en', 'ca_fr')
          content_fr_page = File.read(content_fr).gsub(' "', '"').gsub('"', '""').gsub(/\n/, '').force_encoding("ASCII-8BIT")

        elsif content.include?('ca_fr')
          content_en = content.gsub('ca_fr', 'ca_en')
          content_en_page = File.read(content_en).gsub(' "', '"').gsub('"', '""').gsub(/\n/, '').force_encoding("ASCII-8BIT")
        end



        if impex_page['page_title'] == 'homepage'
          append_to_file impex_content_file, :verbose => false do
            "\n# Homepage \nINSERT_UPDATE CMSParagraphComponent;$contentCV[unique=true];uid[unique=true];content[lang=$lang];restrictions(name)\n;;HomepageComponent#{mm_config['week']};\"#{content_page}\";Time Restriction #{mm_config['week']};\n"
          end
        end

        if mm_config['special_event']
          append_to_file impex_content_file, :verbose => false do
              "\n;;HeaderPromotionalBannerComponent;\"<p><img src=""//media.aldoshoes.com/content/uat/black-friday-1/images/freeshipping-blackfriday.gif"" width=""752"" height=""77"" alt="""" /></p>\";Time Restriction #{mm_config['week']};\n"
          end
        end

        head_content_path = File.join(build_dir, '/head.html')
        head_content = File.read(head_content_path).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")

        append_to_file impex_content_file, :verbose => false do
            "\n# Header Component\n;;HTMLHeaderComponent#{mm_config['week']};\"#{head_content}\";Time Restriction #{mm_config['week']};\n"
        end
        footer_content_path = File.join(build_dir, '/footer.html')
        footer_content = File.read(footer_content_path).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")

        append_to_file impex_content_file, :verbose => false do
            "\n# Footer Component\n;;HTMLFooterComponent#{mm_config['week']};\"#{footer_content}\";Time Restriction #{mm_config['week']};\n"
        end

        # Generate the rest of the content
        unless content.include?('ca_en') || content.include?('ca_fr')
          append_to_file impex_content_file, :verbose => false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]\n\n"
          end
        else
          #binding.pry
          if content.include?('ca_en')
            append_to_file impex_content_file, :verbose => false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]\n\n"
            end
          elsif content.include?('ca_fr')
            append_to_file impex_content_file, :verbose => false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=en]\n\n"
            end
          end
        end
        # binding.pry
        unless impex_page['type'] == 'homepage'

          apply_restriction_config = "\n\n#In this section you are tying your time restricted content to a category id. You can also put in a current (not time restricted) landing page or banner\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)\n\n"

          append_to_file impex_content_file, :verbose => false do
              apply_restriction_config
          end

          unless locale == 'ca_en' || locale == 'ca_fr'
            insert_into_file impex_content_file, :before => apply_restriction_config, :verbose => false do
                "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config['previous_campaign']};<ignore>;;#{impex_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config['week']};<ignore>;;#{impex_page['type']};#{campaign_start};#{campaign_end};\"#{content_page}\"\n"
            end
          end

          if content.include?('ca_en')
            #binding.pry
            insert_into_file impex_content_file, :before => apply_restriction_config, :verbose => false do
                "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config['previous_campaign']};<ignore>;;#{impex_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config['week']};<ignore>;;#{impex_page['type']};#{campaign_start};#{campaign_end};\"#{content_page}\";\"#{content_fr_page}\"\n"
            end
          elsif content.include?('ca_fr')
            insert_into_file impex_content_file, :before => apply_restriction_config, :verbose => false do
                "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config['previous_campaign']};<ignore>;;#{impex_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config['week']};<ignore>;;#{impex_page['type']};#{campaign_start};#{campaign_end};\"#{content_page}\";\"#{content_en_page}\"\n"
            end
          end

          insert_into_file impex_content_file, :after => apply_restriction_config, :verbose => false do
              "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";"";"";#{impex_page['page_title']}#{mm_config['previous_campaign']},#{impex_page['page_title']}#{mm_config['week']};\n"
          end

          if impex_page.include?("sub_pages")
            if File.exist?(File.join(build_dir.to_s, impex_page['sub_pages'][0]['page_file']))
              impex_page['sub_pages'].each do |sub_page|
                sub_content = File.join(build_dir, sub_page['page_file'])
                sub_content_page = File.read(sub_content).gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT") unless File.file?(sub_content)

                previous_sublp = "##{sub_page['page_title']}\n;#{sub_page['page_title'].capitalize.gsub(' ','')}#{mm_config['previous_campaign']};<ignore>;;#{sub_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n"
                current_sublp = ";#{sub_page['page_title'].capitalize.gsub(' ','')}#{mm_config['week']};<ignore>;;#{sub_page['type']};#{campaign_start};#{campaign_end};\"#{sub_content_page}\"\n"

                insert_into_file impex_content_file, :before => apply_restriction_config, :verbose => false do
                  "#{previous_sublp}#{current_sublp}"
                end

                insert_into_file impex_content_file, :after => apply_restriction_config, :verbose => false do
                  "##{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";"";"";#{impex_page['page_title']}#{mm_config['previous_campaign']},#{sub_page['page_title'].capitalize.gsub(' ','')}#{mm_config['week']};\n"
                end

              end # End of sub_pages generator loop
            else
              say("\s\sError: #{File.join(build_dir, impex_page['sub_pages'][0]['page_file'])} Not found", :red)
              say("\s\s⚠ Ignoring #{impex_page['sub_pages'][0]['page_title']}, because the file is missing.\n\n", :magenta)
            end
          end # End of sub_pages conditional check
        end

      end # End of impex_pages loop
      append_to_file(impex_content_file, "\n#end of Landing Pages and Children Pages\n\n#L3 Pages\n\n#End of L3")

      apply_restriction_l3 = "\n\n#In this section you are tying your time restricted L3 to a category id.\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)\n\n"

      insert_into_file impex_content_file, :before => "#End of L3", :verbose => false do
        apply_restriction_l3
      end

      @l3_build_dir = build_dir + '/l3'

      l3_content_dir = Dir.glob(build_dir + 'l3/*')

      l3_content_dir.each do |l3_content|
          l3_hybris_page_name = l3_content.to_s.gsub(/\d{3,}-/, '').gsub(/\-/,' ').strip
          l3_hybris_id = l3_content.match(/\d{3,}/).to_s
          l3_title = l3_hybris_page_name.gsub(build_dir.to_s, '').gsub('/l3/', '').lstrip
          #binding.pry

          if l3_content.include?('ca_en')
            l3_header = "\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]\n\n#l3"
            insert_into_file impex_content_file, :after => "#L3 Pages", :verbose => false do
              l3_header
            end
          elsif l3_content.include?('ca_fr')

            l3_header = "\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=en]\n\n#l3"

            insert_into_file impex_content_file, :after => "#L3 Pages", :verbose => false do
              l3_header
            end
          else

            l3_header = "\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]\n\n#l3"

            insert_into_file impex_content_file, :after => "#L3 Pages", :verbose => false do
              l3_header
            end

          end
          unless l3_hybris_id.empty?

              l3_content_page = File.read("#{l3_content}/index.html").gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")

              if mm_config['special_event']
                previous_l3 = "\n##{l3_title}\n;#{l3_hybris_id}#{mm_config['previous_campaign']};<ignore>;;CATEGORY_BANNER;#{previous_campaign_start};#{previous_campaign_end};<ignore>\n"

                if l3_content.include?('ca_en')
                  l3_content_page_fr = File.read("#{l3_content.gsub('ca_en', 'ca_fr')}/index.html").gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
                  current_l3 = ";#{l3_hybris_id}#{mm_config['week']};<ignore>;;CATEGORY_BANNER;#{campaign_start};#{campaign_end};\"#{l3_content_page}\";\"#{l3_content_page_fr}\"\n"
                elsif l3_content.include?('ca_fr')
                  l3_content_page_en = File.read("#{l3_content.gsub('ca_fr', 'ca_en')}/index.html").gsub(' "', '"').gsub('"', '""').force_encoding("ASCII-8BIT")
                  current_l3 = ";#{l3_hybris_id}#{mm_config['week']};<ignore>;;CATEGORY_BANNER;#{campaign_start};#{campaign_end};\"#{l3_content_page}\";\"#{l3_content_page_en}\"\n"
                else
                  current_l3 = ";#{l3_hybris_id}#{mm_config['week']};<ignore>;;CATEGORY_BANNER;#{campaign_start};#{campaign_end};\"#{l3_content_page}\"\n"
                end

                insert_into_file impex_content_file, :after => l3_header, :verbose => false do
                  "#{previous_l3}#{current_l3}"
                end

                insert_into_file impex_content_file, :after => apply_restriction_l3, :verbose => false do
                  "\n##{l3_title}\n;;\"#{l3_hybris_id}\";"";"";#{l3_hybris_id}#{mm_config['previous_campaign']},#{l3_hybris_id}#{mm_config['week']};\n"
                end

              else
                append_to_file(impex_content_file, "##{l3_hybris_page_name}\n;;\"#{l3_hybris_id}\";;\"#{l3_content_page}\"\n", :verbose => false)
              end

          end
      end
      say("\s\s☑ Finished to generate the impex content files for #{locale}", :green)
      say("\s\sℹ You can find it in: #{impex_content_file}\n", :blue)

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

  end
end
