require 'middleman-core/cli'
require 'thor'
# require 'pry'
require 'adl-utils/version'
require 'expanded_date'

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

      desc 'impex', Middleman::ADLUTILS::IMPEX_DESC

      def impex
        build_before
        mm_var
      end

      protected

      def upcase_strip(content)
        regex = /[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/
        content.upcase.gsub(/#{regex}/, '')
      end

      def mm_var
        extend Middleman

        mm = ::Middleman::Application.server.inst do
          config[:environment] = :build
        end

        @mm_config = {
          season: mm.config.season,
          campaign: mm.config.campaign,
          week: upcase_strip(mm.config.campaign),
          previous_campaign: upcase_strip(mm.config.previous_campaign),
          campaign_start: mm.config.campaign_start,
          special_event: mm.config.special_event
        }

        generate(@mm_config)
      end

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

      def generate_config(mm_config={})

        impex_config_file = "build/impex/#{ENV['REV']}/1-#{mm_config[:season]}-#{mm_config[:campaign]}_config-#{Time.now.strftime('%y%m%d-%H%M')}.impex"

        create_file impex_config_file, verbose: false

        say("\n### Starting ImpEx Builder Tool ###\n", :green)

        config_file = []
        config_file << '####################################################'
        config_file << '#                    WCMS CONFIG                   #'
        config_file << '####################################################'
        config_file << ''
        config_file << '#### DO NOT MODIFY ####'
        config_file << '# Macros / Replacement Parameter definitions'
        config_file << '$contentCatalog=aldoCommerceContentCatalog'
        config_file << '$caProductCatalog=caAldoProductCatalog'
        config_file << '$ukProductCatalog=ukAldoProductCatalog'
        config_file << '$usProductCatalog=usAldoProductCatalog'
        config_file << '$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]'
        config_file << '$caProductCV=catalogVersion(catalog(id[default=$caProductCatalog]),version[default=\'Staged\'])[unique=true,default=$caProductCatalog:Staged]'
        config_file << '$ukProductCV=catalogVersion(catalog(id[default=$ukProductCatalog]),version[default=\'Staged\'])[unique=true,default=$ukProductCatalog:Staged]'
        config_file << '$usProductCV=catalogVersion(catalog(id[default=$usProductCatalog]),version[default=\'Staged\'])[unique=true,default=$usProductCatalog:Staged]'
        config_file << '$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog'
        config_file << '#### END DO NOT MODIFY ####'
        config_file << ''
        config_file << '#### CREATE COMPONENTS FOR HOME PAGE (header, content & footer) ####'
        config_file << '# CMS Paragraph Components'
        config_file << 'INSERT_UPDATE CMSParagraphComponent;$contentCV[unique=true];uid[unique=true];name;&componentRef'
        config_file << ";;HomepageComponent#{mm_config[:previous_campaign]};Home Page Component for #{mm_config[:previous_campaign]};HomepageComponent#{mm_config[:previous_campaign]};"
        config_file << ";;HTMLHeaderComponent#{mm_config[:previous_campaign]};HTML Header Component for #{mm_config[:previous_campaign]};HTMLHeaderComponent#{mm_config[:previous_campaign]};"
        config_file << ";;HTMLFooterComponent#{mm_config[:previous_campaign]};HTML Footer Component for #{mm_config[:previous_campaign]};HTMLFooterComponent#{mm_config[:previous_campaign]};"
        config_file << ';;PermanentFooterComponent;Permanent Footer Component;PermanentFooterComponent;'
        config_file << ";;HomepageComponent#{mm_config[:week]};Home Page Component for #{mm_config[:week]};HomepageComponent#{mm_config[:week]};"
        config_file << ";;HTMLHeaderComponent#{mm_config[:week]};HTML Header Component for #{mm_config[:week]};HTMLHeaderComponent#{mm_config[:week]};"
        config_file << ";;HTMLFooterComponent#{mm_config[:week]};HTML Footer Component for #{mm_config[:week]};HTMLFooterComponent#{mm_config[:week]};"
        config_file << ''
        config_file << '#### ADD THE ABOVE COMPONENTS TO THE RIGHT HOME PAGE PLACEHOLDERS ####'
        config_file << '# Once you create the new paragraph component above, add it to the component list separated by a comma like I did with MegaPromoBanner2 below'
        config_file << 'INSERT_UPDATE ContentSlot;$contentCV[unique=true];uid[unique=true];name;active;cmsComponents(&componentRef)'
        config_file << ";;HTMLHeaderSlot;HTML Header Slot;true;HTMLHeaderComponent#{mm_config[:previous_campaign]},HTMLHeaderComponent#{mm_config[:week]};"
        config_file << ";;FooterSlot;Footer;true;PermanentFooterComponent,HTMLFooterComponent#{mm_config[:previous_campaign]},HTMLFooterComponent#{mm_config[:week]};"
        config_file << ";;Section1Slot-Homepage;Section1 Slot for Homepage;true;HomepageComponent#{mm_config[:previous_campaign]},HomepageComponent#{mm_config[:week]};"

        append_to_file impex_config_file, verbose: false do
          config_file.join("\n")
        end

        say("\n Finished generating config file", :green)

      end


      def impexify_content(content)
        content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
        content.force_encoding('ASCII-8BIT')
      end

      def generate_content(mm_config={}, impexer_config={}, locale)
        FileUtils.rm("build/impex/#{ENV['REV']}/#{locale}.impex") if options[:force]

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

        time_restriction = []
        time_restriction << '####################################################'
        time_restriction << '#                TIME RESTRICTIONS                 #'
        time_restriction << '####################################################'
        time_restriction << '#Create time restrictions here then add time restriction name to the end of each component'
        time_restriction << 'INSERT_UPDATE CMSTimeRestriction;$contentCV[unique=true];uid[unique=true];name;activeFrom[dateformat=dd.MM.yyyy HH:mm:ss];activeUntil[dateformat=dd.MM.yyyy HH:mm:ss]'
        time_restriction << ";;Time-Restriction-#{mm_config[:previous_campaign]};Time Restriction #{mm_config[:previous_campaign]};#{previous_campaign_start};#{previous_campaign_end};"
        time_restriction << ";;Time-Restriction-#{mm_config[:week]};Time Restriction #{mm_config[:week]};#{campaign_start};#{campaign_end};\n\n"

        append_to_file impex_content_file, verbose: false do
          time_restriction.join("\n")
        end

        #### End Of Time Restriction

        # =>  Read page and get content
        impexer_config[:impex_pages].each do |impex_page|

          content = File.join(build_dir, impex_page['page_file'])
          content_page = impexify_content(File.read(content))

          if content.include?('ca_en')
            content_fr = content.gsub('ca_en', 'ca_fr')
            content_fr_page = impexify_content(File.read(content_fr))
          elsif content.include?('ca_fr')
            content_en = content.gsub('ca_fr', 'ca_en')
            content_en_page = impexify_content(File.read(content_en))
          end


          append_to_file impex_content_file, verbose: false do
            "\n# Homepage\nINSERT_UPDATE CMSParagraphComponent;$contentCV[unique=true];uid[unique=true];content[lang=$lang];restrictions(name)\n;;HomepageComponent#{mm_config[:week]};\"#{content_page}\";Time Restriction #{mm_config[:week]};\n"
          end if impex_page['page_title'] == 'homepage'

          append_to_file impex_content_file, verbose: false do
            "\n;;HeaderPromotionalBannerComponent;\"<p><img src=" "//media.aldoshoes.com/content/uat/black-friday-1/images/freeshipping-blackfriday.gif" " width=" "752" " height=" "77" " alt=" "" " /></p>\";Time Restriction #{mm_config[:week]};\n"
          end if mm_config[:special_event]

          head_content_path = File.join(build_dir, '/head.html')
          head_content =impexify_content(File.read(head_content_path))

          append_to_file impex_content_file, verbose: false do
            "\n# Header Component\n;;HTMLHeaderComponent#{mm_config[:week]};\"#{head_content}\";Time Restriction #{mm_config[:week]};\n"
          end

          footer_content_path = File.join(build_dir, '/footer.html')
          footer_content = impexify_content(File.read(footer_content_path))

          append_to_file impex_content_file, verbose: false do
            "\n# Footer Component\n;;HTMLFooterComponent#{mm_config[:week]};\"#{footer_content}\";Time Restriction #{mm_config[:week]};\n"
          end

          # Generate the rest of the content
          if !content.include?('ca_en') || !content.include?('ca_fr')
            append_to_file impex_content_file, verbose: false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]\n\n"
            end
          else
            if content.include?('ca_en')
              append_to_file impex_content_file, verbose: false do
                "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]\n\n"
              end
            elsif content.include?('ca_fr')
              append_to_file impex_content_file, verbose: false do
                "\n# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=en]\n\n"
              end
            end
          end

          unless impex_page['type'] == 'homepage'
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
            elsif content.include?('ca_fr')
              insert_into_file impex_content_file, :before => apply_restriction_config, verbose: false do
                "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{previous_campaign_start};#{previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{campaign_start};#{campaign_end};\"#{content_page}\";\"#{content_en_page}\"\n"
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
        append_to_file impex_content_file, verbose: false do
          "\n#end of Landing Pages and Children Pages\n\n#L3 Pages\n\n#End of L3"
        end

        apply_restriction_l3 = "\n\n#In this section you are tying your time restricted L3 to a category id.\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)\n\n"

        insert_into_file impex_content_file, :before => '#End of L3', verbose: false do
          apply_restriction_l3
        end

        # =>  Setup the working directory
        @l3_build_dir = build_dir + '/l3'
        # =>  Create an array with all the directories inside the working dir
        l3_content_dir = Dir.glob(build_dir + 'l3/*')
        # say("Generating L3 for #{locale}...", :yellow)
        # append_to_file(impex_content_file, "\n#L3 Content Page\n", verbose: false)
        l3_content_dir.each do |l3_content|
          l3_hybris_page_name = l3_content.to_s.gsub(/\d{3,}-/, '').gsub(/\-/, ' ').strip
          l3_hybris_id = l3_content.match(/\d{3,}/).to_s
          l3_title = l3_hybris_page_name.gsub(build_dir.to_s, '').gsub('/l3/', '').lstrip
          #binding.pry

          if l3_content.include?('ca_en')
            l3_header = "\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]\n\n#l3"
            insert_into_file impex_content_file, :after => '#L3 Pages', verbose: false do
              l3_header
            end
          elsif l3_content.include?('ca_fr')

            l3_header = "\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=en]\n\n#l3"

            insert_into_file impex_content_file, :after => '#L3 Pages', verbose: false do
              l3_header
            end

          else

            l3_header = "\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]\n\n#l3"

            insert_into_file impex_content_file, :after => '#L3 Pages', verbose: false do
              l3_header
            end

          end
          unless l3_hybris_id.empty?

            l3_content_page = impexify_content(File.read("#{l3_content}/index.html"))

            if mm_config[:special_event]
              previous_l3 = "\n##{l3_title}\n;#{l3_hybris_id}#{mm_config[:previous_campaign]};<ignore>;;CATEGORY_BANNER;#{previous_campaign_start};#{previous_campaign_end};<ignore>\n"

              if l3_content.include?('ca_en')
                l3_content_page_fr = impexify_content(File.read("#{l3_content.gsub('ca_en', 'ca_fr')}/index.html").gsub(' "', '"'))
                current_l3 = ";#{l3_hybris_id}#{mm_config[:week]};<ignore>;;CATEGORY_BANNER;#{campaign_start};#{campaign_end};\"#{l3_content_page}\";\"#{l3_content_page_fr}\"\n"
              elsif l3_content.include?('ca_fr')
                l3_content_page_en = impexify_content(File.read("#{l3_content.gsub('ca_fr', 'ca_en')}/index.html"))
                current_l3 = ";#{l3_hybris_id}#{mm_config[:week]};<ignore>;;CATEGORY_BANNER;#{campaign_start};#{campaign_end};\"#{l3_content_page}\";\"#{l3_content_page_en}\"\n"
              else
                current_l3 = ";#{l3_hybris_id}#{mm_config[:week]};<ignore>;;CATEGORY_BANNER;#{campaign_start};#{campaign_end};\"#{l3_content_page}\"\n"
              end

              insert_into_file impex_content_file, :after => l3_header, verbose: false do
                "#{previous_l3}#{current_l3}"
              end

              insert_into_file impex_content_file, :after => apply_restriction_l3, verbose: false do
                "\n##{l3_title}\n;;\"#{l3_hybris_id}\";"";"";#{l3_hybris_id}#{mm_config[:previous_campaign]},#{l3_hybris_id}#{mm_config[:week]};\n"
              end

            else
              append_to_file impex_content_file, verbose: false do
                "##{l3_hybris_page_name}\n;;\"#{l3_hybris_id}\";;\"#{l3_content_page}\"\n"
              end
            end

          end
        end
        say("\s\s Finished to generate the impex content files for #{locale}", :green)
        say("\s\s You can find it in: #{impex_content_file}\n", :blue)

      end # End of the generate method

      def print_usage_and_die(message)
        usage_path    = File.join(File.dirname(__FILE__), '..', '..', 'USAGE')
        usage_message = File.read(usage_path)

        raise Error, "ERROR: #{message}\n#{usage_message}"
      end
    end
  end
end
