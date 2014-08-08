require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'

module Middleman
  module Cli

    class HomepageImpex < Thor

      no_commands do

        def mm_config
          InitVar.new.homepage_config
        end

        def homepage_impex
          GenerateHomepage.new.generate_config(mm_config)
        end
      end

    end

    class GenerateHomepage < Thor
      include Thor::Actions

      no_commands do

        def impexify_content(content)
          content = content.gsub(' "', '"').gsub('"', '""').gsub(/\n/, '')
          content.force_encoding('ASCII-8BIT')
        end

        def upcase_strip(content)
          (content.upcase.gsub(/[^a-zA-Z 0-9]/, '')).gsub(/\s/,'-')
        end

        def content_var(mm_config={}, locale)

          impex_property = Hash.new

          config = {
              build_dir: mm_config.build_dir,
              season: mm_config.season,
              campaign: mm_config.campaign,
              week: upcase_strip(mm_config.campaign),
              locales: mm_config[:hybris_locales],
          }

          if locale.to_s.include?('ca_en')
            impex_property[:country_code] = 'ca'
            impex_property[:lang] = 'en'
          end

          if locale.to_s.include?('uk_en_UK')
            impex_property[:lang] = 'en_UK'
            impex_property[:country_code] = 'uk'
          end

          if locale.to_s.include?('us_en_US')
            impex_property[:lang] = 'en_US'
            impex_property[:country_code] = 'us'
          end

          generate_homepage(config.merge(impex_property), locale)
        end

        def generate_config(mm_config={})
          Middleman::Cli::GenerateHomepage.source_root('../')
          @template_dir = File.join(File.dirname(__FILE__), '/data/')
          campaign =  mm_config[:campaign]
          output_file = "#{output_dir}/#{gentime}_#{campaign}_config.impex"
          say("\n══ Generating impex config file", :green)
          copy_file(File.join( @template_dir + 'impex_config.tt'), output_file)
          mm_config[:hybris_locales].each do |loc|
            next if loc.to_s == 'ca_fr'
            content_var(mm_config, loc)
          end
        end

        def gentime
          Time.now.strftime('%y-%m-%d_%H.%M')
        end

        def output_dir
          "build/impex/#{ENV['REV']}"
        end

        def generate_homepage(mm_config={}, locale)
          build_dir = File.join(mm_config[:build_dir].to_s, locale.to_s)
          campaign =  mm_config[:campaign]
          country_code = mm_config[:country_code]
          impex_homepage_file = "#{output_dir}/#{gentime}_#{campaign}-homepage_#{country_code}.impex"

          opts = Hash.new

          opts[:homepage_content] = File.read(File.join(build_dir, 'index.html'))
          opts[:homepage_content_fr] = page_fr(fr_swap(File.join(build_dir, 'index.html'))) if locale.to_s =='ca_en'
          opts[:head_content] = impexify_content(File.read(File.join(build_dir, '/head.html')))
          opts[:footer_content] = impexify_content(File.read(File.join(build_dir, '/footer.html')))

          template(File.join( @template_dir + 'impex_content.erb'), impex_homepage_file, mm_config.merge(opts))

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

      end

    end
  end
end
