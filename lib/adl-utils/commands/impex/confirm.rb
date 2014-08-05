require 'middleman-core/cli'
require 'thor'
require 'pry'
require 'adl-utils/version'

module Middleman
  module Cli

    class ConfirmImpex < Thor
      include Thor::Actions

      no_commands do

        def landing_page_impex(file_destination, page={}, content)
          append_to_file file_destination, :verbose => false do
            "##{page['page_title']}\n;;#{page['hybris_id']};\"#{content}\";\"\";\n"
          end
        end

        def category_banner_impex(file_destination, page={}, content)
          append_to_file file_destination, :verbose => false do
            "##{page['page_title']}\n;;#{page['hybris_id']};;\"#{content}\"\n"
          end
        end

        def confirm_generate(config={}, locale, impex_file)

          build_dir = Pathname.new("build/#{config[:revision]}/hybris/" + locale)
          confirm_file = impex_file

          # =>  Read page and get content
          config[:impex_data].to_a.each do |page|

            content = File.join(build_dir, page['page_file'])
            content_page = File.read(content).gsub(' "', '"').gsub('"', '""').force_encoding('ASCII-8BIT')

            next if page['page_title'] == 'homepage'
            binding.pry
            # Generate the rest of the content

            append_to_file confirm_file, :verbose => false do
              "\n# Landing Pages & Category Banner\n$productCatalog=#{config[:country_code]}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\nUPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang]\n"
            end

            if page['type'] == 'landing page'
              landing_page_impex(confirm_file, page, content_page)
            else
              category_banner_impex(confirm_file, page, content_page)
            end

            if page.include?('sub_pages')
              sub_pages(build_dir, page)
            end # End of sub_pages conditional check

          end # End of confirm_impex_pages loop

        end # End of the generate method

        def sub_pages(build_dir, page)
          page['sub_pages'].each do |sub_page|
            sub_content = File.join(build_dir, sub_page['page_file'])
            sub_content_page = File.read(sub_content).gsub(' "', '"').gsub('"', '""').force_encoding('ASCII-8BIT')
            say("Reading & Generating #{page['page_title']} #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)

            if sub_page['type'] == 'landing page'
              say("Reading & Generating #{sub_page['page_title']} using #{sub_page['type']} template...", :yellow)
              append_to_file(confirm_file, "##{page['page_title']} #{sub_page['page_title']}\n;;#{sub_page['hybris_id']};\"#{sub_content_page}\";\"\";\n", :verbose => false)
            elsif sub_page['type'] == 'category banner'
              append_to_file(confirm_file, "##{page['page_title']} #{sub_page['page_title']}\n;;#{sub_page['hybris_id']};;\"#{sub_content_page}\"\n", :verbose => false)
            else
              append_to_file(confirm_file, "##{page['page_title']} #{sub_page['page_title']}\n;;#{sub_page['hybris_id']};\"#{sub_content_page}\"\n", :verbose => false)
            end # End of check for page type inside sub_pages
          end # End of sub_pages generator loop
          
        end
      end
    end
  end
end