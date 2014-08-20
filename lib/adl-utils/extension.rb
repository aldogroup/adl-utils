class ADLUTILSLiveBuild < ADLUTILS
  def initialize(app, options_hash={}, &block)
    super
    app.extend ZippBuild
  end

  module ZipBuild
    class << self
      def registered(app)
        app.after_build do |builder|
          builder.in_root do
            builder.run "zip -qr build/#{app.config.campaign}.zip build/*"
          end
        end
      end

      # alias :included :registered
    end
  end

  # ::Middleman::Extensions.register(:zip_build, ZipBuild)
end
