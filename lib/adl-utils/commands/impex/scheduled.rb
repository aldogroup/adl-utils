require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'
require 'adl-utils/commands/impex/confirm'
require 'expanded_date'

module Middleman
  module Cli

    #
    # Create Initialize Middleman variables and execute the generator
    #
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

    #
    # Create Impex CLI Script.
    #
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

        def schedule_fetch(page, period, locale)
          begin
           locale = locale_converter(locale)
           scheduled = 'schedule_' + period
            ref = page[scheduled.to_s].to_sym
            page_schedule = date_parse("#{mm_config[ref][period][locale].date} #{mm_config[ref][period][locale].time}")
           return page_schedule
          rescue
            campaign_schedule = "#{mm_config[:campaign_start][locale].date} #{mm_config[:campaign_start][locale].time}"
             if period == 'start'
              page_schedule =  date_parse(campaign_schedule)
             else
               page_schedule = campaign_scheduled_end(date_parse(campaign_schedule))
             end
             return page_schedule
           end
         end

        def locale_converter(locale)
          case locale
            when 'ca_en', 'ca_fr'
              return 'ca'
            when 'us_en_US'
              return 'us'
            else 'uk_en_UK'
              return 'uk'
          end
        end

        def content_var(mm_config={}, locale)
          impex_property = Hash.new
          if locale == 'ca_en'
            impex_property[:country_code] = 'ca'
            impex_property[:date_hour] = "#{mm_campaign_start.ca.date} #{mm_campaign_start.ca.time}"
            impex_property[:campaign_start_date] = date_parse(impex_property[:date_hour])
            impex_property[:lang] = 'en'
          elsif locale == 'uk_en_UK'
            impex_property[:lang] = 'en_UK'
            impex_property[:country_code] = 'uk'
            impex_property[:date_hour] = "#{mm_campaign_start.uk.date} #{mm_campaign_start.uk.time}"
            impex_property[:campaign_start_date] = date_parse(impex_property[:date_hour])
          elsif locale == 'us_en_US'
            impex_property[:lang] = 'en_US'
            impex_property[:country_code] = 'us'
            impex_property[:date_hour] = "#{mm_campaign_start.us.date} #{mm_campaign_start.us.time}"
            impex_property[:campaign_start_date] = date_parse(impex_property[:date_hour])
          end

          mm_config = mm_config.merge!(impex_property)
          generate_header(mm_config, locale)
        end

        def apply_restriction_config
          restriction_config = []
          restriction_config << "\n"
          restriction_config << '#In this section you are tying your time restricted content to a category id.'
          restriction_config << '#You can also put in a current (not time restricted) landing page or banner'
          restriction_config << 'UPDATE Category;$catalogVersion;code[unique=true];scheduledContent(&Item)'
          restriction_config << "\n"
          restriction_config.join("\n")
        end

        def leveltwo_routine(impex_page, locale, start_date, end_date)
          build_dir = Pathname.new("build/#{mm_config[:revision]}/hybris/" + locale)

          if File.exist?(File.join(build_dir.to_s, impex_page['sub_pages'][0]['page_file']))
            impex_page['sub_pages'].each do |sub_page|

              sub_content = File.join(build_dir, sub_page['page_file'])
              sub_content_page = impexify_content(File.read(sub_content))
              sub_content_fr = fr_swap(sub_content)
              sub_content_fr_page = page_fr(sub_content_fr)

              if sub_page.schedule_start.nil?
                puts "Sub has it's own schedule"
                sub_page_start_date = start_date
              else
                puts "Sub hasn't it's own schedule"
                sub_page_start_date = schedule_fetch(sub_page, 'start', locale)
              end

              if sub_page.schedule_end.nil?
                sub_page_end_date = end_date
              else
                sub_page_end_date = schedule_fetch(sub_page, 'end', locale)
              end

              unless mm_config[:country_code].include?('ca')
                current_sublp = ";#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};<ignore>;;#{sub_page['type']};#{sub_page_start_date};#{sub_page_end_date};\"#{sub_content_page}\"\n"
                insert_into_file @impex_content_file, before: apply_restriction_config, verbose: false do
                  "#{current_sublp.force_encoding('ASCII-8BIT')}"
                end
              end

              if sub_content.include?('ca_en')
                current_sublp_fr = ";#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};<ignore>;;#{sub_page['type']};#{sub_page_start_date};#{sub_page_end_date};\"#{sub_content_page}\";\"#{sub_content_fr_page}\"\n"
                insert_into_file @impex_content_file, before: apply_restriction_config, verbose: false do
                  "#{current_sublp_fr.force_encoding('ASCII-8BIT')}"
                end
              end
              # Would need a check if CATEGORY BANNER or LANDING PAGE for an appropriate semi-colon.
              insert_into_file @impex_content_file, after: apply_restriction_config, verbose: false do
                "##{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";#{sub_page['page_title'].capitalize.gsub(' ', '')}#{mm_config[:week]};\n"
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
          (DateTime.parse(date) - ((0.01 / 24) / 36)).strftime('%d.%m.%Y %H:%M:%S')
        end

        def pretty_golive
          DateTime.parse(mm_config[:campaign_start_date].to_s).strftime('%d-%m-%Y_%H.%M.%S')
        end

        def pretty_golive_confirm
          (DateTime.parse(mm_config[:campaign_start_date]) + 1.hours).strftime('%d-%m-%Y_%H.%M.%S')
        end

        def generate_header(mm_config={}, locale)
          @impex_content_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y-%m-%d_%H.%M')}_#{short_brand}-#{country_code.upcase}_LP_SCHEDULE_#{mm_config[:campaign]}.impex"
          confirm_impex_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y-%m-%d_%H.%M')}_#{short_brand}-#{country_code.upcase}_LP_CONFIRM_#{mm_config[:campaign]}.impex"

          create_file @impex_content_file, verbose: false
          create_file confirm_impex_file, verbose: false

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

        def short_brand
          if mm_config[:brand] == 'Aldo-Shoes'
            return 'ALDO'
          elsif mm_config[:brand] == 'Call-it-Spring'
            return 'CIS'
          elsif mm_config[:brand] == 'Globo-Shoes'
            return 'GLOBO'
          elsif mm_config[:brand] == 'Globo-Shoes'
            return 'LB'
          else
            return 'UNKNOWN'
          end
        end

        def product_catalog
          if mm_config[:brand] == 'Aldo-Shoes'
            return mm_config[:country_code]+ 'AldoProductCatalog'
          elsif mm_config[:brand] == 'Call-it-Spring'
            return mm_config[:country_code]+ 'CISProductCatalog'
          elsif mm_config[:brand] == 'Globo-Shoes'
            return mm_config[:country_code]+ 'GloboProductCatalog'
          else
            return mm_config[:country_code]+ 'LBProductCatalog'
          end
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
            start_date = schedule_fetch(impex_page, 'start', locale)
            # puts start_date
            # if content.include? 'handbags'
            #   binding.pry
            # end

            end_date = schedule_fetch(impex_page, 'end', locale)

            append_to_file @impex_content_file, verbose: false do
              "# Landing Pages & Category Banner\n$lang=#{mm_config[:lang]}\n$productCatalog=#{product_catalog}\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\n"
            end

            # Generate the rest of the content
            if mm_config[:country_code].include?('ca')
              append_to_file @impex_content_file, verbose: false do
                "\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy HH:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang];bannerContent[lang=fr]\n\n"
              end
            else
              append_to_file @impex_content_file, verbose: false do
                "\n#In this section you add the time restriction and the content tied to that time restriction\nINSERT_UPDATE ScheduledCategoryContent;&Item;pk[unique=true];$catalogVersion;contentType(code);startDate[dateformat=dd.MM.yyyy HH:mm:ss];endDate[dateformat=dd.MM.yyyy hh:mm:ss];bannerContent[lang=$lang]\n\n"
              end
            end

            append_to_file @impex_content_file, verbose: false do
              apply_restriction_config
            end

            unless mm_config[:country_code].include?('ca')
              page_content = ";#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{start_date};#{end_date};\"#{impexify_content(content_page)}\"\n"
              insert_into_file @impex_content_file, before: apply_restriction_config, verbose: false do
                page_content.force_encoding('ASCII-8BIT')
              end
            end

            if content.include?('ca_en')
              page_content = ";#{impex_page['page_title']}#{mm_config[:week]};<ignore>;;#{impex_page['type']};#{start_date};#{end_date};\"#{impexify_content(content_page)}\";\"#{content_fr_page}\"\n"
              insert_into_file @impex_content_file, before: apply_restriction_config, verbose: false do
                page_content.force_encoding('ASCII-8BIT')
              end
            end

            insert_into_file @impex_content_file, after: apply_restriction_config, verbose: false do
              "##{impex_page['page_title']}\n;;\"#{impex_page['hybris_id']}\";#{impex_page['page_title']}#{mm_config[:week]};\n"
            end

            leveltwo_routine(impex_page, locale, start_date, end_date) if impex_page.include?('sub_pages') # End of sub_pages conditional check

          end # End of impex_pages loop

          throw :done
        end # End of the generate method

      end
    end
  end
end
