require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli

    class InitVar

      def upcase_strip(content)
        (content.upcase.gsub(/[^a-zA-Z 0-9]/, '')).gsub(/\s/,'')
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
          special_event: @mm.config.special_event,
          locales: @mm.config[:hybris_locales],
          revision: @mm.revision,
          source_root: @mm.root,
          impex_data: @mm.data.impex_data
        }
      end

      def homepage_config
        mm_instance
        return @mm.config
      end

    end

    class Impex < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :impex

      desc 'impex', Middleman::ADLUTILS::IMPEX_DESC
      method_option :homepage
      def impex

        if yes?('== Do you want to build your project first ?')
          run("VER=hybris REV=#{ENV['REV']} middleman build --clean", {:verbose => false}) || exit(1)
        end

        if options[:homepage]
          require 'adl-utils/commands/impex/homepage'
          Middleman::Cli::HomepageImpex.new.homepage_impex
        else
          require 'adl-utils/commands/impex/scheduled'
          Middleman::Cli::ScheduledImpex.new.shedimpex
        end
      end
    end
  end
end
