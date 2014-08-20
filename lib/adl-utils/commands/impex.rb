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

        @config = {
          season: @mm.config.season,
          campaign: @mm.config.campaign,
          week: upcase_strip(@mm.config.campaign),
          campaign_start: @mm.config.campaign_start,
          locales: @mm.config[:hybris_locales],
          revision: @mm.revision,
          source_root: @mm.root,
          impex_data: @mm.data.impex_data,
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

      def impex
        if yes?('== Do you want to build your project first ?')
          run("VER=hybris REV=#{ENV['REV']} middleman build --clean", verbose: false) || exit(1)
        end

        if options[:homepage]
          require 'adl-utils/commands/impex/homepage'
          Middleman::Cli::HomepageImpex.new.homepage_impex
        elsif options[:l3]
          require 'adl-utils/commands/impex/level3'
          Middleman::Cli::LevelThree.new.l3
        else
          require 'adl-utils/commands/impex/scheduled'
          Middleman::Cli::ScheduledImpex.new.shedimpex
        end
      end
    end
  end
end
