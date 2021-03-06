require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli
    #
    # Initialize Middleman Variable
    #
    class InitVar
      def upcase_strip(content)
        (content.upcase.gsub(/[^a-zA-Z 0-9]/, '')).gsub(/\s/, '')
      end

      def mm_instance
        extend Middleman

        @mm = ::Middleman::Application.server.inst do
          config[:environment] = :build
        end
      end

      # define project variable
      def project_config
        mm_instance
        # binding.pry
        @config = {
          brand: @mm.config.banner,
          season: @mm.config.season,
          campaign: @mm.config.campaign,
          week: upcase_strip(@mm.config.campaign),
          locales: @mm.config[:hybris_locales],
          revision: @mm.revision,
          source_root: @mm.root,
          campaign_start: @mm.data.deploy_config.campaign_schedule,
          sale_schedule: @mm.data.deploy_config.sale_schedule,
          clearance_schedule: @mm.data.deploy_config.clearance_schedule,
          impex_data: @mm.data.deploy_config.pages,
          generate_l3: @mm.config.generate_l3
        }
      end

      def homepage_config
        mm_instance
        return @mm.config
      end
    end

    #
    # Create Impex CLI Script.
    #
    class Impex < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :impex

      desc 'impex', Middleman::ADLUTILS::IMPEX_DESC
      method_option :homepage, desc: 'Will generate impex for the homepage without time restriction.'
      method_option :l3, desc: 'Will generate all the level3 pages. (generate_l3 must be set to true in config.rb)'
      method_option :brands, desc: 'Will generate all the brand pages. (generate_brands must be set to true in config.rb)'

      def impex
        buildtask = Middleman::Cli::BuildBefore.new
        ENV['REV'] = 'dev' if ENV['REV'].nil?
        buildtask.build(ENV['REV'], 'hybris')

        if options[:homepage]
          require 'adl-utils/commands/impex/homepage'
          Middleman::Cli::HomepageImpex.new.homepage_impex
        elsif options[:l3]
          require 'adl-utils/commands/impex/level3'
          Middleman::Cli::LevelThree.new.l3
        elsif options[:brands]
          require 'adl-utils/commands/impex/brands'
          Middleman::Cli::Brands.new.brands
        else
          require 'adl-utils/commands/impex/scheduled'
          Middleman::Cli::ScheduledImpex.new.shedimpex
        end
      end
    end
  end
end
