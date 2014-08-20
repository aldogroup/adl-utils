require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'

module Middleman
  module Cli
    # This class provides a "deploy" command for the middleman CLI.
    class LevelThree < Thor
      include Thor::Actions

      no_commands do
        def l3
          project_config
        end

        def upcase_strip(content)
          regex = /[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/
          content.upcase.gsub(/#{regex}/, '')
        end

        def project_config
          extend Middleman

          mm = ::Middleman::Application.server.inst do
            config[:environment] = :build
          end

          @mm_var = {
            season: mm.config.season,
            campaign: mm.config.campaign,
            week: upcase_strip(mm.config.campaign),
            locales: mm.config[:hybris_locales],
            revision: mm.revision,
            source_root: mm.root,
            impex_data: mm.data.impex_data
          }
          generate(@mm_var)
        end

        def impexer_config
          {
            revision: ENV['REV'],
            locales: %w(ca_en ca_fr uk_en_UK us_en_US),
            source_root: File.dirname(__FILE__),
            usage_path: File.join(File.dirname(__FILE__), 'impex/data/'),
            # impex_data_file: impex_yml_file,
            # impex_data: File.read(impex_yml_file),
            # impex_pages: YAML.load(File.read(impex_yml_file))
          }
        end

        def generate(mm_config={})
          mm_config = @mm_var
          impexer_config[:locales].each do |loc|
            @impex_file = "build/impex/#{impexer_config[:revision]}/#{Time.now.strftime('%y%m%d-%H%M')}_#{mm_config[:campaign]}-level3-#{loc}.impex"
            create_file @impex_file, verbose: false
            if loc == 'ca_en' || loc == 'ca_fr'
              country_code = 'ca'
              if loc == 'ca_en'
                lang = 'en'
              else
                lang = 'fr'
              end
            end
            if loc == 'uk_en_UK'
              lang = 'en_UK'
              country_code = 'uk'
            end
            if loc == 'us_en_US'
              lang = 'en_US'
              country_code = 'us'
            end
            append_to_file @impex_file, verbose: false do
              "$lang=#{lang}\n$productCatalog=#{country_code}AldoProductCatalog\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\n"
            end
            append_to_file @impex_file, verbose: false do
              'UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)'
            end
            generate_l3(loc, mm_config)
          end
        end

        def generate_l3(locale, _mm_config={})
          @locale = locale
          build_dir = Pathname.new("build/#{impexer_config[:revision]}/hybris/" + locale)
          # l3_build_dir = build_dir + '/l3'
          # =>  Create an array with all the directories inside the working dir
          l3_content_dir = Dir.glob(build_dir + 'l3/*')
          say("Generating L3 for #{locale}...", :yellow)
          append_to_file(@impex_file, "\n#L3 Content Page\n", verbose: false)
          l3_content_dir.each do |l3_content|
            l3_hybris_page_name = l3_content.to_s.gsub(/\d{3,}-/, '').gsub(/\-/, ' ').strip
            l3_hybris_id = l3_content.match(/\d{3,}/).to_s
            unless l3_hybris_id.empty?
              l3_content_page = File.read("#{l3_content}/index.html").gsub(' "', '"').gsub('"', '""').force_encoding('ASCII-8BIT')
              append_to_file(@impex_file, "##{l3_hybris_page_name}\n;;#{l3_hybris_id};;\"#{l3_content_page}\";\"\"\n", verbose: false)
            end
          end
          say("\s\s Finished to generate the impex content files for #{locale}", :green)
          say("\s\s You can find it in: #{@impex_file}\n", :blue)
        end
      end
    end
  end
end
