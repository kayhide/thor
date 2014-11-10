require 'pry'
require 'fileutils'
require 'tmpdir'
require 'kconv'
require 'csv'
require 'thor'
require 'active_support/core_ext'

class Deaff < Thor::Group
  include Thor::Actions

  class Link
    attr_accessor :ziplink, :display, :value
    def initialize row
      @ziplink, @value, @display = *row
    end
    def ord_str separator = ','
      @value.each_char.map(&:ord).map(&:to_s).join(separator)
    end
    def ziplink_host
      @ziplink_host ||= URI.parse(@ziplink).host
    end
    def ziplink_path
      @ziplink_path ||= URI.parse(@ziplink).path
    end
  end

  argument :src_dir
  class_option :zip, type: :boolean, aliases: '-z', default: false,
    desc: 'Create zip file'
  class_option :keep, type: :boolean, aliases: '-k', default: false,
    desc: 'Keep working copy'

  def load_links
    top_page = open(File.join(src_dir, 'index.html')).read
    @deaff_links_filename = '.deaff'
    csv = CSV.read(@deaff_links_filename)
    @links = csv.map{|row| Link.new row}
    @links.select! do |link|
      (link.display =~ /^http/) && top_page.include?(link.ziplink_host)
    end
    @links.each do |link|
      say link.ziplink, :blue
    end
  end

  def build
    @site_label = File.basename src_dir
    self.class.source_paths << File.expand_path(src_dir)

    if options[:keep]
      @base_dir = File.join('tmp', self.class.name.demodulize.downcase, @site_label)
    else
      @base_dir = Dir.mktmpdir
    end
    say "working in: #{@base_dir}", :cyan

    @original_dir = File.join(@base_dir, 'source')
    @source_dir = File.join(@base_dir, 'source')
    @build_dir = File.join(@base_dir, 'build')

    empty_directory @base_dir
    directory File.expand_path(src_dir), @original_dir
  end

  def utf8
    files = Dir[File.join(@source_dir, '**/*.html'), File.join(@source_dir, '**/*.css')]
    files.each do |src|
      text = nil
      open(src) do |input|
        text = input.read.toutf8
      end
      open(src, 'w') do |output|
        output << text.gsub(/shift_jis|sjis/i, 'UTF-8').gsub("\r", '')
      end
    end
  end

  def process_htmls
    files = Dir[File.join(@source_dir, '**/*.html')]
    files.each do |src|
      insert_into_file src, <<EOS, before: /(?<=\n)\s*<\/head>/i
<script type="text/javascript" src="https://code.jquery.com/jquery-1.11.1.min.js"></script>
EOS

      pattern = @links.map{|l| Regexp.escape(l.ziplink_path)}.join('|')
      gsub_file src, /[^"]*(#{pattern})/ do |m|
        @links.find{|l| m.include? l.ziplink_path}.display
      end

      links_map = @links.map{|l| [l.display, l.ord_str]}.to_h
      insert_into_file src, <<EOS, before: /(?<=\n)\s*<\/body>/i
<script>
(function() {
  var links;
  links = #{links_map.to_json};

  $(function() {
    return setTimeout((function(_this) {
      return function() {
        var link, obj, _i, _len, _ref;
        _ref = document.getElementsByTagName('a');
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          link = _ref[_i];
          if (obj = links[link.href]) {
            $(link).data('value', obj);
            $(link).click(function() {
              var href;
              href = this.href;
              setTimeout((function(_this) {
                return function() {
                  return _this.href = href;
                };
              })(this), 1000);
              this.href = eval('String.fromCharCode(' + $(this).data('value') + ')');
              return true;
            });
            link;
          }
        }
        return null;
      };
    })(this), 1000);
  });
}).call(this);
</script>
EOS
    end

    empty_directory @build_dir
    FileUtils.cp_r File.join(@source_dir, '.'), @build_dir
  end

  def zip
    return unless options[:zip]
    zip_file = "#{@site_label}.zip"
    remove_file zip_file
    inside File.dirname(@build_dir) do
      basename = File.basename @build_dir
      run "zip -r '#{zip_file}' #{basename}"
    end
    FileUtils.mv File.join(File.dirname(@build_dir), zip_file), zip_file
  end

  def clean
    return if options[:keep]
    remove_dir @base_dir
  end
end
