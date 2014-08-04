require 'middleman-core/cli'
require 'thor'
require 'pry'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli

    class ScheduledImpex < Thor

      no_commands do
        def shedimpex(mm_config)
          # binding.pry
          GenerateScheduled.new.generate_scheduled(mm_config)
        end
      end

    end

    class GenerateScheduled < Thor
      include Thor::Actions

      no_commands do

        def generate_scheduled(mm_config={})
          # generate_config(mm_config)
          # binding.pry
          mm_config[:locales].reject{|l| l == :ca_fr}.each do |loc|
            content_var(mm_config, loc.to_s)
          end
        end

        def impexify_content(content)
          content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
          content.force_encoding('ASCII-8BIT')
        end

        def date_parse(value)
          DateTime.parse(value).strftime('%d.%m.%Y %H:%M:%S')
        end

        def content_var(mm_config={}, locale)

          # =>  Setup locale & country_code for impex file generation
          mm_campaign_start = mm_config[:campaign_start]

          impex_property = Hash.new
              #{:country_code, :date_hour, :campaign_start, :lang}

          if locale == 'ca_en'
            impex_property[:country_code] = 'ca'
            impex_property[:date_hour] = "#{mm_campaign_start['ca'][0]} #{mm_campaign_start['ca'][1]}"
            impex_property[:campaign_start] = date_parse(impex_property[:date_hour])
            impex_property[:lang] = 'en'
          end

          if locale == 'uk_en_UK'
            impex_property[:lang] = 'en_UK'
            impex_property[:country_code] = 'uk'
            impex_property[:date_hour] = "#{mm_campaign_start['uk'][0]} #{mm_campaign_start['uk'][1]}"
            impex_property[:campaign_start] = date_parse(impex_property[:date_hour])
          end

          if locale == 'us_en_US'
            impex_property[:lang] = 'en_US'
            impex_property[:country_code] = 'us'
            impex_property[:date_hour] = "#{mm_campaign_start['us'][0]} #{mm_campaign_start['us'][1]}"
            impex_property[:campaign_start] = date_parse(impex_property[:date_hour])
          end
          mm_config = mm_config.merge(impex_property)
          # binding.pry
          generate_header(mm_config, locale)
        end

        def leveltwo_routine(mm_config={}, impex_page)
          if File.exist?(File.join(@build_dir.to_s, impex_page['sub_pages'][0]['page_file']))
            impex_page['sub_pages'].each do |sub_page|
              sub_content = File.join(@build_dir, sub_page['page_file'])
              sub_content_page = impexify_content(File.read(sub_content)) unless File.file?(sub_content)

              previous_sublp = "##{sub_page['page_title']}\n;#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:previous_campaign]};<ignore>;;#{sub_page['type']};#{@previous_campaign_start};#{@previous_campaign_end};<ignore>\n"
              current_sublp = ";#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};<ignore>;;#{sub_page['type']};#{mm_config[:campaign_start]};#{@campaign_end};\"#{sub_content_page}\"\n"

              insert_into_file @impex_content_file, :before => @apply_restriction_config.to_sentence, verbose: false do
                "#{previous_sublp}#{current_sublp}"
              end

              insert_into_file @impex_content_file, :after => @apply_restriction_config.to_sentence, verbose: false do
                "##{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";" ";" ";#{impex_page['page_title']}#{mm_config[:previous_campaign]},#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};\n"
              end

            end # End of sub_pages generator loop
          else
            say("\s\sError: #{File.join(@build_dir, impex_page['sub_pages'][0]['page_file'])} Not found", :red)
            say("\s\s Ignoring #{impex_page['sub_pages'][0]['page_title']}, because the file is missing.\n\n", :magenta)
          end
        end
        
        def generate_header(mm_config={}, locale)

          ########################
          #### Hybris ImpEx Header
          ########################
          hybris_header = []
          hybris_header << '#Hybris Header'
          hybris_header << '$contentCatalog=aldoCommerceContentCatalog'
          hybris_header << '$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]'
          hybris_header << '$picture=media(code, $contentCV);'
          hybris_header << '$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog'
          hybris_header << "$lang=#{mm_config[:lang]}"
          hybris_header << "$countryCode=#{country_code}$siteResource_content=$countryCode!!$lang!!jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n\n"

          ###############################
          #### End Of Hybris ImpEx Header
          ###############################

          @build_dir = Pathname.new("build/#{mm_config[:revision]}/hybris/" + locale)

          unless locale == 'ca_en' || locale == 'ca_fr'
            @impex_content_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y%m%d-%H%M')}_#{mm_config[:campaign]}-scheduled-for-#{mm_config[:campaign_start]}_#{locale}.impex"
            create_file @impex_content_file, verbose: false
            append_to_file @impex_content_file, verbose: false do
              hybris_header.join("\n")
            end
          end

          if locale == 'ca_en'
            # binding.pry
            @impex_content_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y%m%d-%H%M')}_#{mm_config[:campaign]}-scheduled-for-#{mm_config[:campaign_start]}_#{country_code}.impex"
            create_file @impex_content_file, verbose: false
            append_to_file @impex_content_file, verbose: false do
              hybris_header.join("\n")
            end
          end


          ##############################
          #### Start Of Time Restriction
          ##############################
          @campaign_end = (DateTime.parse(mm_config[:campaign_start]).end_of_next_month + 1).strftime('%d.%m.%Y %H:%M:%S')
          @previous_campaign_start = (DateTime.parse(campaign_start) - 10).strftime('%d.%m.%Y %H:%M:%S')
          @previous_campaign_end = (DateTime.parse(campaign_start) - ((0.01 / 24)/36)).strftime('%d.%m.%Y %H:%M:%S')
          
          generate_content(mm_config, locale)
        end
        def country_code
          mm_config[:country_code]
        end

        def campaign_start
          mm_config[:campaign_start]
        end

        def impex_pages
          mm_config[:impex_data].to_a
        end

        def content
          File.join(@build_dir, impex_page['page_file'])
        end

        def content_page
          impexify_content(File.read(content))
        end

        def content_fr
          content.gsub('ca_en', 'ca_fr')
        end

        def content_page_fr
          impexify_content(File.read(content_fr))
        end

        def generate_content(mm_config={}, locale)

          say("\n\n Generating impex content files for #{country_code}", :blue)

          # Read page and get content
          impex_pages.each do |impex_page|

            append_to_file @impex_content_file, verbose: false do
              "# Landing Pages & Category Banner\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]"
            end

            # Generate the rest of the content
            if !content.include?('ca_en') || !content.include?('ca_fr')
              append_to_file @impex_content_file, verbose: false do
                "UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]"
              end
            elsif content.include?('ca_en')
              append_to_file @impex_content_file, verbose: false do
                "UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy hh:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]"
              end
            end

            unless impex_page['type'] == 'homepage'
              @apply_restriction_config = []
              @apply_restriction_config << "#In this section you are tying your time restricted content to a category id.\n"
              @apply_restriction_config << "#You can also put in a current (not time restricted) landing page or banner"
              @apply_restriction_config << "Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)\n\n"

              append_to_file @impex_content_file, verbose: false do
                @apply_restriction_config.join("\n")
              end

              # binding.pry
              if !country_code.include?('ca')
                insert_into_file @impex_content_file, :before => @apply_restriction_config.to_sentence, verbose: false do
                  "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{@previous_campaign_start};#{@previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{mm_config[:campaign_start]};#{@campaign_end};\"#{content_page}\"\n"
                end
              end

              if content.include?('ca_en')
                insert_into_file @impex_content_file, :before => @apply_restriction_config.to_sentence, verbose: false do
                  "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{@previous_campaign_start};#{@previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{mm_config[:campaign_start]};#{@campaign_end};\"#{content_page}\";\"#{content_fr_page}\"\n"
                end
              end

              insert_into_file @impex_content_file, :after => @apply_restriction_config.to_sentence, verbose: false do
                "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";"";"";#{impex_page['page_title']}#{mm_config[:previous_campaign]},#{impex_page['page_title']}#{mm_config[:week]};\n"
              end

              leveltwo_routine(mm_config, impex_page) if impex_page.include?('sub_pages') # End of sub_pages conditional check
            end

          end # End of impex_pages loop

        end # End of the generate method

      end

    end
  end
end