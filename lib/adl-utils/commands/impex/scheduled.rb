require 'middleman-core/cli'
require 'thor'
require 'pry'
require 'adl-utils/version'
require 'adl-utils/commands/impex/confirm'
require 'expanded_date'

module Middleman
  module Cli

    class ScheduledImpex < Thor

      no_commands do

        def mm_config
          InitVar.new.project_config
        end

        def shedimpex
          GenerateScheduled.new.generate_scheduled(mm_config)
        end
      end

    end

    class GenerateScheduled < Thor
      include Thor::Actions

      no_commands do
        def reset_var
          @mm_config.delete(:country_code)
          @mm_config.delete(:lang)
          @mm_config.delete(:date_hour)
        end

        def generate_scheduled(config={})
          @mm_config = config
          config[:locales].each do |loc|
            next if loc.to_s == 'ca_fr'
            reset_var unless loc.to_s == 'ca_en'
            catch(:done) { content_var(config, loc.to_s) }
          end
        end

        def mm_config
          @mm_config
        end

        def impexify_content(content)
          content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
          content.force_encoding('ASCII-8BIT')
        end

        def date_parse(value)
          DateTime.parse(value).strftime('%d.%m.%Y %H:%M:%S')
        end

        def mm_campaign_start
          mm_config[:campaign_start]
        end

        def content_var(mm_config={}, locale)

          impex_property = Hash.new

          if locale == 'ca_en'
            impex_property[:country_code] = 'ca'
            impex_property[:date_hour] = "#{mm_campaign_start['ca'][0]} #{mm_campaign_start['ca'][1]}"
            impex_property[:campaign_start_date] = date_parse(impex_property[:date_hour])
            impex_property[:lang] = 'en'
          elsif locale == 'uk_en_UK'
            impex_property[:lang] = 'en_UK'
            impex_property[:country_code] = 'uk'
            impex_property[:date_hour] = "#{mm_campaign_start['uk'][0]} #{mm_campaign_start['uk'][1]}"
            impex_property[:campaign_start_date] = date_parse(impex_property[:date_hour])
          elsif locale == 'us_en_US'
            impex_property[:lang] = 'en_US'
            impex_property[:country_code] = 'us'
            impex_property[:date_hour] = "#{mm_campaign_start['us'][0]} #{mm_campaign_start['us'][1]}"
            impex_property[:campaign_start_date] = date_parse(impex_property[:date_hour])
          end
          
          mm_config = mm_config.merge!(impex_property)
          generate_header(mm_config, locale)
        end

        def apply_restriction_config
          restriction_config = []
          restriction_config << '#In this section you are tying your time restricted content to a category id.'
          restriction_config << "\n"
          restriction_config << '#You can also put in a current (not time restricted) landing page or banner'
          restriction_config << 'Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)'
          restriction_config << "\n\n"
          return restriction_config.join("\n")
        end

        def leveltwo_routine(impex_page, locale)

          build_dir = Pathname.new("build/#{mm_config[:revision]}/hybris/" + locale)

          if File.exist?(File.join(build_dir.to_s, impex_page['sub_pages'][0]['page_file']))
            impex_page['sub_pages'].each do |sub_page|

              sub_content = File.join(build_dir, sub_page['page_file'])
              sub_content_page = impexify_content(File.read(sub_content)) unless File.file?(sub_content)

              previous_sublp = "##{sub_page['page_title']}\n;#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:previous_campaign]};<ignore>;;#{sub_page['type']};#{@previous_campaign_start};#{@previous_campaign_end};<ignore>\n"
              current_sublp = ";#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};<ignore>;;#{sub_page['type']};#{mm_config[:campaign_start_date]};#{@campaign_end};\"#{sub_content_page}\"\n"

              insert_into_file @impex_content_file, :before => apply_restriction_config, verbose: false do
                "#{previous_sublp.force_encoding('ASCII-8BIT')}#{current_sublp.force_encoding('ASCII-8BIT')}"
              end

              insert_into_file @impex_content_file, :after => apply_restriction_config, verbose: false do
                "##{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\" \";\" \";#{impex_page['page_title']}#{mm_config[:previous_campaign]},#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};\n"
              end

            end # End of sub_pages generator loop
          else
            say("\s\sError: #{File.join(build_dir, impex_page['sub_pages'][0]['page_file'])} Not found", :red)
            say("\s\s Ignoring #{impex_page['sub_pages'][0]['page_title']}, because the file is missing.\n\n", :magenta)
          end
        end

        def campaign_scheduled_end(date)
          (DateTime.parse(date).end_of_next_month + 1).strftime('%d.%m.%Y %H:%M:%S')
        end

        def new_last_campaign_start(date)
          (DateTime.parse(date) - 10).strftime('%d.%m.%Y %H:%M:%S')
        end

        def new_last_campaign_end(date)
          (DateTime.parse(date) - ((0.01 / 24)/36)).strftime('%d.%m.%Y %H:%M:%S')
        end

        def pretty_golive
          DateTime.parse(mm_config[:campaign_start_date].to_s).strftime('%d-%m-%Y_%H.%M.%S')
        end

        def pretty_golive_confirm
          (DateTime.parse(mm_config[:campaign_start_date]) + 1.hours).strftime('%d-%m-%Y_%H.%M.%S')
        end

        def generate_header(mm_config={}, locale)
          # hybris_header = []
          # hybris_header << '#Hybris Header'
          # hybris_header << '$contentCatalog=aldoCommerceContentCatalog'
          # hybris_header << '$contentCV=catalogVersion(CatalogVersion.catalog(Catalog.id[default=$contentCatalog]),CatalogVersion.version[default=Staged])[default=$contentCatalog:Staged]'
          # hybris_header << '$picture=media(code, $contentCV);'
          # hybris_header << '$siteResource=jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog'
          # hybris_header << "$lang=#{mm_config[:lang]}"
          # hybris_header << "$countryCode=#{country_code}$siteResource_content=$countryCode!!$lang!!jar:com.aldo.hybris.initialdata.setup.InitialDataSystemSetup&/aldoinitialdata/import/contentCatalogs/$contentCatalog\n\n"
          @impex_content_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y%m%d-%H%M')}_#{mm_config[:campaign]}-scheduled-for-#{pretty_golive}_#{country_code}.impex"
          confirm_impex_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y%m%d-%H%M')}_#{mm_config[:campaign]}-confirm-on-#{pretty_golive_confirm}_#{country_code}.impex"

          create_file @impex_content_file, verbose: false
          create_file confirm_impex_file, verbose: false

          # append_to_file confirm_impex_file, verbose: false do
          #   hybris_header.join("\n")
          # end
          #
          # append_to_file @impex_content_file, verbose: false do
          #   hybris_header.join("\n")
          # end
          #end

          ##############################
          #### Start Of Time Restriction
          ##############################

          @campaign_end = campaign_scheduled_end(mm_config[:campaign_start_date])
          @previous_campaign_start = new_last_campaign_start(mm_config[:campaign_start_date])
          @previous_campaign_end = new_last_campaign_end(mm_config[:campaign_start_date])
          ConfirmImpex.new.confirm_generate(mm_config, locale, confirm_impex_file)
          generate_content(locale)
        end

        def country_code
          mm_config[:country_code]
        end

        def campaign_start
          mm_config[:campaign_start_date]
        end

        def impex_pages
          mm_config[:impex_data].to_a
        end

        def content_page
          impexify_content(File.read(content))
        end

        def fr_swap(content)
          content.gsub('ca_en', 'ca_fr')
        end

        def page_fr(content_fr)
          impexify_content(File.read(content_fr))
        end

        # Still Works needs to be done here (Method is too long)
        def generate_content(locale)

          say("\n\n Generating impex content files for #{country_code}", :blue)

          build_dir = Pathname.new("build/#{mm_config[:revision]}/hybris/" + locale)

          # Read page and get content
          impex_pages.each do |impex_page|

            next if impex_page['type'] == 'homepage'

            content = File.join(build_dir, impex_page['page_file'])
            content_page = File.read(content)

            content_fr = fr_swap(content)
            content_fr_page = page_fr(content_fr)

            append_to_file @impex_content_file, verbose: false do
              "# Landing Pages & Category Banner\n$productCatalog=#{mm_config[:country_code]}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]"
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

            append_to_file @impex_content_file, verbose: false do
              apply_restriction_config
            end

            unless mm_config[:country_code].include?('ca')
              page_content = "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{@previous_campaign_start};#{@previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{mm_config[:campaign_start_date]};#{@campaign_end};\"#{content_page}\"\n"
              insert_into_file @impex_content_file, :before => apply_restriction_config, verbose: false do
                page_content.force_encoding('ASCII-8BIT')
              end
            end

            if content.include?('ca_en')
              page_content = "\n##{impex_page['page_title']}\n;#{impex_page['page_title']}#{mm_config[:previous_campaign]};<ignore>;;#{impex_page['type']};#{@previous_campaign_start};#{@previous_campaign_end};<ignore>\n;#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{mm_config[:campaign_start_date]};#{@campaign_end};\"#{content_page}\";\"#{content_fr_page}\"\n"
              insert_into_file @impex_content_file, :before => apply_restriction_config, verbose: false do
                page_content.force_encoding('ASCII-8BIT')
              end
            end

            insert_into_file @impex_content_file, :after => apply_restriction_config, verbose: false do
              "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";\"\";\"\";#{impex_page['page_title']}#{mm_config[:previous_campaign]},#{impex_page['page_title']}#{mm_config[:week]};\n"
            end

            leveltwo_routine(impex_page, locale) if impex_page.include?('sub_pages') # End of sub_pages conditional check

          end # End of impex_pages loop

          throw :done

        end # End of the generate method

      end

    end
  end
end
