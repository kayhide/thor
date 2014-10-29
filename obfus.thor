require 'pry'
require 'fileutils'
require 'tmpdir'
require 'kconv'
require 'thor'

class Obfus < Thor::Group
  include Thor::Actions

  argument :src_dir

  def build
    @site_label = File.basename src_dir
    self.class.source_paths << File.expand_path(src_dir)

    # @base_dir = File.join('obfus', @site_label)
    @base_dir = Dir.mktmpdir
    say "working in: #{@base_dir}", :cyan

    @original_dir = File.join(@base_dir, 'original')
    @source_dir = File.join(@base_dir, 'source')
    @build_dir = File.join(@base_dir, 'build')

    remove_dir @base_dir

    empty_directory @base_dir
    directory src_dir, @original_dir

    @htmls = Dir[File.join(@original_dir, '**/*.html')]
    @stylesheets = Dir[File.join(@original_dir, '**/*.css')]
    @javascripts = Dir[File.join(@original_dir, '**/*.js')]
  end

  def munch
    FileUtils.cp_r @original_dir, @source_dir

    run "munch --html #{@htmls.join ','} --css #{@stylesheets.join ','}"
    files = Dir[File.join(@original_dir, '**/*.opt.*')]
    files.each do |src|
      dst = src.sub(/^#{@original_dir}/, @source_dir).sub(/\.opt/, '')
      FileUtils.mkdir_p File.dirname(dst)
      FileUtils.mv src, dst
    end
  end

  def utf8
    files = Dir[File.join(@source_dir, '**/*.html'), File.join(@source_dir, '**/*.css')]
    files.each do |src|
      text = nil
      open(src) do |input|
        text = input.read.toutf8
      end
      open(src, 'w') do |output|
        output << text.gsub(/shift_jis|sjis/i, 'utf-8').gsub("\r", '')
      end
    end
  end

  def middleman_init
    unless File.exists? File.join(@base_dir, 'config.rb')
      inside @base_dir do
        create_file 'Gemfile', <<EOS
source 'http://rubygems.org'
gem "middleman", "~>3.3.6"
gem 'middleman-minify-html'
EOS

        create_file 'config.rb', <<EOS
set :stylesheets_dir, 'css'
set :javascripts_dir, 'js'
set :images_dir, 'img'
configure :build do
  activate :minify_css
  activate :minify_javascript
  activate :minify_html
end
EOS

        run 'bundle -j4'
      end
    end
  end

  def middleman_build
    inside @base_dir do
      run 'bundle exec middleman build'
      files = Dir[File.join(@original_dir, '.*')].reject do |file|
        ['.', '..'].include? File.basename(file)
      end
      files.each do |src|
        dst = src.sub(/^#{@original_dir}/, @source_dir)
        FileUtils.cp src, dst
      end
    end
  end

  def zip
    zip_file = "#{@site_label}.zip"
    remove_file zip_file
    inside File.dirname(@build_dir) do
      basename = File.basename @build_dir
      run "zip -r '#{zip_file}' #{basename}"
    end
    FileUtils.mv File.join(File.dirname(@build_dir), zip_file), zip_file
  end

  def clean
    remove_dir @base_dir
  end
end
