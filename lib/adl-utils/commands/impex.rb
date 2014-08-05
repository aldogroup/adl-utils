require 'middleman-core/cli'
require 'thor'
require 'pry'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli

    class InitVar

      def upcase_strip(content)
        regex = /[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/
        content.upcase.gsub(/#{regex}/, '')
      end

      def project_config
        extend Middleman

        mm = ::Middleman::Application.server.inst do
          config[:environment] = :build
        end

        @config = {
          season: mm.config.season,
          campaign: mm.config.campaign,
          week: upcase_strip(mm.config.campaign),
          previous_campaign: upcase_strip(mm.config.previous_campaign),
          campaign_start: mm.config.campaign_start,
          special_event: mm.config.special_event,
          locales: mm.config[:hybris_locales],
          revision: mm.revision,
          source_root: mm.root,
          impex_data: mm.data.impex_data
        }
      end
    end

    class Impex < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :impex

      desc 'impex', Middleman::ADLUTILS::IMPEX_DESC

      def impex

        if yes?('== Do you want to build your project first ?')
          run("VER=hybris REV=#{ENV['REV']} middleman build --clean") || exit(1)
        end

        # mm_config = InitVar.new.project_config
        require 'adl-utils/commands/impex/scheduled'
        Middleman::Cli::ScheduledImpex.new.shedimpex
      end
    end
  end
end
