require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'

module Middleman
  module Cli
    #
    # Create Brands impex file.
    #
    class Brands < Thor
      include Thor::Actions

      no_commands do
        def brands
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
            brand: mm.config.banner,
            season: mm.config.season,
            campaign: mm.config.campaign,
            week: upcase_strip(mm.config.campaign),
            locales: mm.config[:hybris_locales],
            revision: mm.revision,
            source_root: mm.root,
            impex_data: mm.data.deploy_config.pages
          }
          generate(@mm_var)
        end

        def impexer_config
          {
            revision: ENV['REV'],
            locales: @mm_var[:locales],
            source_root: File.dirname(__FILE__),
            usage_path: File.join(File.dirname(__FILE__), 'impex/data/'),
          }
        end

        def short_brand
          if mm_config[:brand] == 'Aldo-Shoes'
            return 'ALDO'
          elsif mm_config[:brand] == 'Call-it-Spring'
            return 'CIS'
          elsif mm_config[:brand] == 'Globo-Shoes'
            return 'GLOBO'
          elsif mm_config[:brand] == 'Little-Burgundy-Shoes'
            return 'LB'
          else
            return 'UNKNOWN'
          end
        end

        def mm_config
          return @mm_var
        end

        def generate(mm_config={})
          # mm_config = @mm_var
          impexer_config[:locales].each do |l|
            loc = l.to_s
            # @impex_file = "build/impex/#{impexer_config[:revision]}/#{Time.now.strftime('%y%m%d-%H%M')}_#{mm_config[:campaign]}-levebrands-#{loc}.impex"
            @impex_file = "build/impex/#{ENV['REV']}/#{Time.now.strftime('%y-%m-%d_%H.%M')}_#{short_brand}-#{loc.upcase}_BRANDS_#{mm_config[:season]}.impex"
            create_file @impex_file, verbose: false
            if loc == 'ca_en' || loc == 'ca_fr'

              if loc == 'ca_en'
                lang = 'en'
              else
                lang = 'fr'
              end
              (product_catalog == 'Aldo-Shoes') ? country_code = '' : country_code = 'ca'
            end
            if loc == 'uk_en_UK'
              lang = 'en_UK'
              country_code = 'uk'
            end
            if loc == 'us_en_US'
              lang = 'en_US'
              country_code = 'us'
            end
            # country_code = locale_converter(loc)
            # binding.pry
            append_to_file @impex_file, verbose: false do
              "$lang=#{lang}\n$productCatalog=#{country_code}#{product_catalog}\n$catalogVersion=catalogversion(catalog(id[default=$productCatalog]),version[default='Staged'])[unique=true,default=$productCatalog:Staged]\n"
            end
            append_to_file @impex_file, verbose: false do
              'UPDATE Category;$catalogVersion;code[unique=true];landingPage[lang=$lang];categoryBanner[lang=$lang];scheduledContent(&Item)'
            end
            generate_brands(loc, mm_config)
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

        def product_catalog
          if @mm_var[:brand] == 'Aldo-Shoes'
            return 'AldoProductCatalog'
          elsif @mm_var[:brand] == 'Call-it-Spring'
            return 'CISSapFmsProductCatalog'
          elsif @mm_var[:brand] == 'Globo-Shoes'
            return 'GloboProductCatalog'
          else
            return 'LBProductCatalog'
          end
        end

        def generate_brands(locale, _mm_config={})
          @locale = locale
          build_dir = Pathname.new("build/#{impexer_config[:revision]}/hybris/" + locale)
          # =>  Create an array with all the directories inside the working dir
          brands_content_dir = Dir.glob(build_dir + 'brands/*')
          say("Generating L3 for #{locale}...", :yellow)
          append_to_file(@impex_file, "\n#L3 Content Page\n", verbose: false)
          # binding.pry
          brands_content_dir.each do |brands_content|
            brands_hybris_page_name = brands_content.to_s.gsub(/\d{3,}-/, '').gsub(/\-/, ' ').strip
            brands_hybris_id = brands_content.match(/\d{3,}/).to_s
            unless brands_hybris_id.empty?
              brands_content_page = File.read("#{brands_content}/index.html").gsub(' "', '"').gsub('"', '""').force_encoding('ASCII-8BIT')
              append_to_file(@impex_file, "##{brands_hybris_page_name}\n;;#{brands_hybris_id};;\"#{brands_content_page}\";\"\"\n", verbose: false)
            end
          end
          say("\s\s Finished to generate the impex content files for #{locale}", :green)
          say("\s\s You can find it in: #{@impex_file}\n", :blue)
        end
      end
    end
  end
end
