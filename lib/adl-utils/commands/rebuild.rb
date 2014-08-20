require 'middleman-core/cli'
require 'thor'
require 'pry'
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
        options['environment'] || ENV['REV']
      end

      def version
        options['platform'] || ENV['VER']
      end

      def build(options={})
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

        if Dir.exist?(work_folder)
          FileUtils.rm_rf work_folder
          directory(build_folder + "/#{revision}/#{version}", work_folder, verbose: false)
        else
          directory(build_folder + "/#{revision}/#{version}", work_folder, verbose: false)
        end
      end

      def cleanup(directory_list)
        Dir.chdir(File.join(source_root, work_folder))
        directory_list.each do |rfolder|
          trash_folder = File.join(source_root, work_folder + '/' + rfolder)
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
        homepage_file = File.join(Dir.getwd, Dir.glob('*.html'))
        copy_file homepage_file, work_folder + '/homepage_' + folder + '.html'
        page_folders
      end

      def page_folders
        Dir.glob('*').select { |fn| File.directory?(fn) }
      end

      def searchrename(locale_folder, page)
        # Search for the index.html file
        page_folder = File.join(locale_folder, page)
        Dir.chdir(page_folder)
        Dir.glob('*').each do |f|
          if ['.', '..'].include?(f)
            next
          end
          current_dir = Dir.glob('*')
          if current_dir.length > 1
            current_dir.each do |sf|
              if File.extname(sf) == '.html'
                new_filename = work_folder + '/' + page + '_' + folder + '.html'
                sf = work_folder + '/' + folder + '/' + sf
                copy_file sf, new_filename
              else
                Dir.chdir(File.join(page_folder, sf))
                current_file = File.join(Dir.getwd, Dir.glob('*'))
                new_filename = work_folder + '/' + page + '-' + sf + '_' + folder + '.html'
                copy_file current_file, new_filename
              end
            end
          else
            current_file = File.join(Dir.getwd, Dir.glob('*'))
            new_filename = work_folder + '/' + page + '_' + folder + '.html'
            copy_file current_file, new_filename
          end

        end
      end

      def restructure(options={})
        puts '== Rebuilding'
        # Set variables
        source_root = ENV['MM_ROOT']
        build_folder = 'build'
        # locale_list  = %w(ca-eng ca-fre us uk)

        # Check to see if the build folder exists, kill if it doesn't
        buildcheck(build_folder)

        # Change to build > revision > version directory
        Dir.chdir(work_folder)
        # Grab the list of directories depending on the revision
        # and version that was passed to this method, remove assets folder
        directory_list = Dir.glob('*').select { |fn| File.directory?(fn) }
        directory_list = directory_list.reject { |fn| fn == 'assets' }

        # Delete the sitemap file
        if File.exist?('index.html')
          File.delete('index.html')
        end

        # Loop through all locales folders
        directory_list.each do |folder|

          # Switch into the current locale directory
          dirswitch(folder)

          # Loop over each page folder
          page_folders.each do |page|
            searchrename(locale_folder, page)
          end

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
