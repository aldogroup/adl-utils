require 'middleman-core/cli'
require 'thread'
require 'thor'
require 'pry'
require 'adl-utils/version'

module Middleman
  module Cli
    #
    # Create the confirm impex file.
    #
    class ConfirmImpex < Thor
      include Thor::Actions

      no_commands do

        def confirm_generate(config={}, locale, impex_file)
          @finished = false
          build_dir = Pathname.new("build/#{config[:revision]}/hybris/" + locale)
          @confirm_file = impex_file
          @locale = locale
          @config = config

          # =>  Read page and get content
          append_to_file @confirm_file, verbose: false do
            "# Landing Pages & Category Banner\n$lang=#{config[:lang]}\n$productCatalog=#{config[:country_code]}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)\n"
          end
          append_to_file(@confirm_file, "#end content\n", verbose: false)

          append_to_file(@confirm_file, "#end subs\n", verbose: false)

          if locale == 'ca_en'
            append_to_file(@confirm_file, "#ca_fr\n", verbose: false)
            append_to_file(@confirm_file, "#sub_fr\n", verbose: false)
          end

          config[:impex_data].to_a.each do |page|
            next if page['page_title'] == 'homepage'
            confirm_page_generator(build_dir, @confirm_file, page, config)
            if page.include?('sub_pages')
              sub_pages(build_dir, page, @confirm_file)
            end # End of sub_pages conditional check
          end # End of confirm_impex_pages loop
        end

        # End of the generate method

        def impexify_content(content)
          content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
          content.force_encoding('ASCII-8BIT')
        end

        def fr_swap(content)
          content.gsub('ca_en', 'ca_fr')
        end

        def page_fr(content_fr)
          impexify_content(File.read(content_fr))
        end

        def landing_page_impex(file_destination, page={}, content)
          if content.include?('ca_fr')
            insert_into_file file_destination, after: "#ca_fr\n", verbose: false do
              "##{page['page_title']}\n;;\"#{page['hybris_id']}\";\"#{content}\";\"\";\"\"\n"
            end
          else
            insert_into_file file_destination, before: "#end content", verbose: false do
              "##{page['page_title']}\n;;\"#{page['hybris_id']}\";\"#{content}\";\"\";\"\"\n"
            end
          end
        end

        def category_banner_impex(file_destination, page={}, content)
          if content.include?('ca_fr')
            insert_into_file file_destination, after: "#ca_fr\n", verbose: false do
              "##{page['page_title']}\n;;\"#{page['hybris_id']}\";;\"#{content}\";\"\"\n"
            end
          else
            insert_into_file file_destination, before: "#end content", verbose: false do
              "##{page['page_title']}\n;;\"#{page['hybris_id']}\";;\"#{content}\";\"\"\n"
            end
          end
        end

        def confirm_page_generator(build_dir, confirm_file, page={}, _config={})
          content = File.join(build_dir, page['page_file'])
          content_page = impexify_content(File.read(content))

          # Generate the rest of the content

          if page['type'] == 'LANDING_PAGE'
            landing_page_impex(confirm_file, page, content_page)
          else
            category_banner_impex(confirm_file, page, content_page)
          end

          if page.include?('sub_pages')
            sub_pages(build_dir, page, confirm_file)
          end # End of sub_pages conditional check
          if content.include?('ca_en')
            build_dir_fr = Pathname.new("build/#{@config[:revision]}/hybris/ca_fr")
            confirm_page_generator_fr(build_dir_fr, @confirm_file, page)
          end
        end

        def sub_pages(build_dir, page, confirm_file)
          begin
            page['sub_pages'].each do |sub_page|
              sub_content = File.join(build_dir, sub_page['page_file'])
              sub_content_page = impexify_content(File.read(sub_content))

              if sub_page['type'] == 'LANDING_PAGE'
                insert_into_file confirm_file, before: "#end subs\n", verbose: false do
                  "##{page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\"#{sub_content_page}\";\"\";\"\"\n"
                end
              elsif sub_page['type'] == 'CATEGORY_BANNER'
                insert_into_file confirm_file, before: "#end subs\n", verbose: false do
                  "##{page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";;\"#{sub_content_page}\";\"\"\n"
                end
              else
                insert_into_file confirm_file, before: "#end subs\n", verbose: false do
                  "##{page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\"#{sub_content_page}\"\n"
                end
              end # End of check for page type inside sub_pages
            end # End of sub_pages generator loop
          end
          @finished = true
          sub_pages_fr(build_dir, page, confirm_file)
        end

        def confirm_page_generator_fr(build_dir, confirm_file, page={})
          content = File.join(build_dir, page['page_file'])
          content_page = impexify_content(File.read(content))

          # Generate the rest of the content
          insert_into_file confirm_file, after: "#end subs\n", verbose: false do
            "\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=fr];categoryBanner[lang=fr];scheduledContent(&Item)\n\n"
          end

          if page['type'] == 'LANDING_PAGE'
            landing_page_impex(confirm_file, page, content_page)
          else
            category_banner_impex(confirm_file, page, content_page)
          end

          if page.include?('sub_pages')
            sub_pages_fr(build_dir, page, confirm_file)
          end
        end

        def sub_pages_fr(build_dir, page, confirm_file)
          begin
            page['sub_pages'].each do |sub_page|
              sub_content = File.join(build_dir, sub_page['page_file'])
              sub_content_page = impexify_content(File.read(sub_content))

              if sub_page['type'] == 'LANDING_PAGE'
                # say("Reading & Generating #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)
                insert_into_file confirm_file, after: "#sub_fr\n", verbose: false do
                  "##{page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\"#{sub_content_page}\";\"\";\"\"\n"
                end
              elsif sub_page['type'] == 'CATEGORY_BANNER'
                insert_into_file confirm_file, after: "#sub_fr\n", verbose: false do
                  "##{page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";;\"#{sub_content_page}\";\"\"\n"
                end
              else
                insert_into_file confirm_file, after: "#sub_fr\n", verbose: false do
                  "##{page['page_title']} #{sub_page['page_title']}\n;;\"#{sub_page['hybris_id']}\";\"#{sub_content_page}\"\n"
                end
              end # End of check for page type inside sub_pages
            end # End of sub_pages generator loop
          end
          # binding.pry
          # @generate_fr if build_dir.to_s.include?('ca_en')
        end
      end
    end
  end
end
