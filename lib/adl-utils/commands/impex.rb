require 'middleman-core/cli'
require 'thor'
require 'pry'
require 'adl-utils/version'
require 'adl-utils/commands/impex/scheduled'
require 'expanded_date'

module Middleman
  module Cli

    class Init
      no_commands do
        def upcase_strip(content)
          regex = /[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/
          content.upcase.gsub(/#{regex}/, '')
        end
        def project_config
          extend Middleman

          mm = ::Middleman::Application.server.inst do
            config[:environment] = :build
          end
          config = {
            season: mm.config.season,
            campaign: mm.config.campaign,
            week: upcase_strip(mm.config.campaign),
            previous_campaign: upcase_strip(mm.config.previous_campaign),
            campaign_start: mm.config.campaign_start,
            special_event: mm.config.special_event
          }
        end
      end
    end

    class Impex < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :impex

      desc 'impex', Middleman::ADLUTILS::IMPEX_DESC

      def impex
        # build_before
        if yes?('== Do you want to build your project first ?')
          BuildBefore.new.build
        end

        mm_config = Init.new.project_config
        # binding.pry
        Middleman::Cli::ScheduledImpex.new.shedimpex(mm_config)
      end
    end
  end
end
