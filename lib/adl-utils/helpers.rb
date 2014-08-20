module Middleman
  class ADLUTILSHelpers < ADLUTILS
    def initialize(app, options_hash={}, &block)
      super

      app.helpers do
        def format_price(price)
          (t(:lang).include? 'ca_fr') ? price + '&thinsp;$' : '$' + price
        end

        def is_ca(lang = 'both')
          case lang
          when 'en'
            (t(:lang) == 'ca_en')
          when 'fr'
            (t(:lang) == 'ca_fr')
          else
            (t(:lang) == 'ca_en' || t(:lang) == 'ca_fr')
          end
        end

        def is_us
          (t(:lang) == 'us_en_US')
        end

        def slim_partial(name, options={}, &block)
          Slim::Template.new("#{name}.slim.erb", options).render(self, &block)
        end

        def page_class
          current_resource.url.sub('.html', '').gsub('/', ' ')
        end

        def sanitize_clean(name)
          I18n.transliterate(name).downcase.gsub(/[\`\~\!\@\#\$\%\^\&\*\(\)\-\=\_\+\[\]\\\;\'\,\.\/\{\}\|\:\"\<\>\?]/, ' ').gsub(/\s+/, '-').gsub(/[^a-z0-9_-]/, '').squeeze('-') unless name.nil?
        end

        def newline2br(longname)
          longname.gsub(/\n/, '<br/>')
        end

        def newspan2br(longname)
          longname.gsub(/\n/, '</span><br/><span>')
        end

        def supprice(text)
          text.gsub(/[\$\£]/, '<sup>\0</sup>')
        end

        def convert_class(width)
          'adl-col' + width.chomp(' columns')
        end

        def getLink(link)
          if version == 'hybris'
            link + '_hybris'
          else
            link
          end
        end

        def run_build
          run('middleman build --clean') || exit(1)
        end
      end
    end
  end
end
