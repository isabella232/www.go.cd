# coding: utf-8
require 'nokogiri'
require 'html-proofer'

namespace :static_checks do
  def should_not_run_external_url_checks?
    if ENV['CI'] || ENV['SNAP_CI']
      false
    else
      ENV['RUN_EXTERNAL_CHECKS'].nil? || ENV['RUN_EXTERNAL_CHECKS'] == 'false'
    end
  end

  options = {
      :disable_external     => true,
      :ignore_urls          => [/([https]:\/\/(localhost)|(github)|(linkedin):*)/],
      :allow_hash_href      => true,
      :allow_missing_href   => true,
      :check_external_hash  => true,
      :href_ignore          => ['/https:\/\/www\.youtube\.com\/.*/'],
      :validation           => {
          :report_invalid_tags  => false,
          :report_script_embeds => false,
          :report_missing_names => false,
      },
      :typhoeus => {
          :followlocation => true,
          :connecttimeout => 500,
      },
      :ignore_missing_alt   => true,
      :log_level            => :info
  }

  task :html_proofer do
    STDERR.puts "WARNING: Not checking outbound links. Set environment variable: " +
                    "RUN_EXTERNAL_CHECKS to 'true' to run them" if should_not_run_external_url_checks?

    puts "\nRunning link checks, html format and verifying that it can be hosted in a subdirectory (relative links):"
    Dir.mktmpdir do |tmpdir|
      cp_r 'build/', File.join(tmpdir, 'subdir')

      cd tmpdir do
        HTMLProofer.check_directory('.', options).run
      end
    end
  end

  task :all => [:html_proofer]
end

task :build do
  Rake::Task['static_checks:all'].invoke
  task :all => [:build, :html_proofer]
end

task publish: [:clean, :build, 'static_checks:all'] do
  if ENV['S3_BUCKET']
    sh('bundle exec middleman s3_sync -i')
  else
    puts "WARNING: Not pushing to S3, since S3_BUCKET is not set"
  end
end

Rake::Task[:publish].prerequisites.unshift "clobber"
