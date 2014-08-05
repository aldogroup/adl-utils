require 'middleman-core/cli'
# require 'pry'
require 'thor'
require 'adl-utils/version'

module Middleman
  module Cli
    # This class provides a "deploy" command for the middleman CLI.
    class LevelThree < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :level3

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc 'level3', Middleman::ADLUTILS::IMPEX_DESC

      def level3
        build_before
        l3_mm_config = Init.new.project_config
        generate(l3_mm_config)
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
        impexer_config[:locales].each do |loc|
          generate_l3(mm_config, impexer_config, loc)
        end
      end

      def impexify_content(content)
        content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
        content.force_encoding('ASCII-8BIT')
      end

      def generate_l3(mm_config={}, impexer_config={}, locale)

        append_to_file impex_content_file, verbose: false do
          "#L3 Pages\n"
        end

        apply_restriction_l3 = []
        apply_restriction_l3 << '#In this section you are tying your time restricted L3 to a category id.'
        apply_restriction_l3 << 'UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)'

        insert_into_file impex_content_file, :after => '#L3 Pages', verbose: false do
          apply_restriction_l3.join("\n")
        end

        # =>  Setup the working directory
        @l3_build_dir = build_dir + '/l3'

        # =>  Create an array with all the directories inside the working dir
        l3_content_dir = Dir.glob(build_dir + 'l3/*')
        l3_content_dir.each do |l3_content|
        l3_hybris_page_name = l3_content.to_s.gsub(/\d{3,}-/, '').gsub(/\-/, ' ').strip
        l3_hybris_id = l3_content.match(/\d{3,}/).to_s
        l3_title = l3_hybris_page_name.gsub(build_dir.to_s, '').gsub('/l3/', '').lstrip


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
    end
    end
  end
end