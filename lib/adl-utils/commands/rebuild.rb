require 'middleman-core/cli'
require 'thor'
require 'adl-utils/version'
require 'expanded_date'

module Middleman
  module Cli
    class Rebuild < Thor
      include Thor::Actions

      check_unknown_options!

      namespace :rebuild

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      desc 'rebuild [options]', Middleman::ADLUTILS::REBUILD_DESC
      method_option 'environment', aliases: '-e', type: :string, desc: 'Call rebuild task'
      method_option 'platform', aliases: '-p', type: :string, desc: 'version (icongo or hybris)'

      def rebuild
        build(options)
        restructure(options)
      end

      protected

      def revision
        rev = options['environment'] || ENV['REV']
        rev = 'dev' if rev.nil?
        rev
      end

      def version
        options['platform'] || ENV['VER']
      end

      def build(_options={})
        if yes?('== Do you want to build your project first ?')
          run("VER=#{version} REV=#{revision} middleman build --clean", verbose: false) || exit(1)
        end
      end

      source_root ENV['MM_ROOT']

      def buildcheck(build_folder)
        unless File.directory?(build_folder)
          puts set_color '== The build folder does not exist', :red
          return
        end

        FileUtils.rm_rf work_folder if Dir.exist?(work_folder)
        directory(build_folder + "/#{revision}/#{version}", work_folder, verbose: false)
      end

      def cleanup(directory_list)
        Dir.chdir(File.join(sourceroot, work_folder))
        directory_list.each do |rfolder|
          trash_folder = File.join(sourceroot, work_folder + '/' + rfolder)
          remove_dir trash_folder
        end
      end

      def work_folder
        'rebuild'
      end

      def sourceroot
        ENV['MM_ROOT']
      end

      def dirswitch(folder)
        locale_folder = File.join(sourceroot, work_folder + '/' + folder)
        Dir.chdir(locale_folder)
        Dir.glob('**/*.html').each do |page|
          current_file = File.join(Dir.getwd, page)
          copy_file current_file, output_file(work_folder, page, folder)
          page_folders
        end
      end

      def output_file(work_folder, page, folder)
        if page == 'index.html' || page == 'footer.html' || page == 'header.html'
          work_folder + '/homepage_' + folder + '.html'
        else
          work_folder + '/' + page.gsub('/', '_').chomp('.html') + '_' + folder + '.html'
        end
      end

      def page_folders
        Dir.glob('*').select { |fn| File.directory?(fn) }
      end

      def restructure(_options={})
        puts '== Rebuilding'

        # Check to see if the build folder exists, kill if it doesn't
        buildcheck('build')

        # Change to build > revision > version directory
        Dir.chdir(work_folder)
        # Grab the list of directories depending on the revision
        # and version that was passed to this method, remove assets folder
        directory_list = page_folders.reject { |fn| fn == 'assets' }

        # Delete the sitemap file
        File.delete('index.html') if File.exist?('index.html')

        # Loop through all locales folders
        directory_list.each do |folder|
          locale_folder = File.join(sourceroot, work_folder + '/' + folder)
          Dir.chdir(locale_folder)

          # Switch into the current locale directory
          dirswitch(folder)

          # Go back to list of locales
          Dir.chdir('..')
        end

        # Cleanup folders
        cleanup(directory_list)

        puts '== Done'
      end
    end
  end
end
