require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'
require 'benchmark'
require_relative 'utils/drive_downloader'
require 'exiftool'
require 'parallel'
require 'digest/sha1'

def date_to_string(timestamp)

  return '' if timestamp.nil?
  DateTime.parse(timestamp.to_s).strftime('%d.%m.%Y').to_s

end

CACHE_DIR = "imgs/gallery"

# Generate output image filename.
def _dest_filename(src_path, options, postfix)

  options_slug = options.gsub(/[^\da-z]+/i, "")
  ext = '.webp' # File.extname(src_path)

  "#{File.basename(src_path, ".*")}_#{options_slug}#{"_" unless postfix == ''}#{postfix}#{ext}"

end

# Build the path strings.
def _paths(img_path, options, postfix)

  src_path = img_path
  raise "Image at #{src_path} is not readable" unless File.readable?(src_path)

  dest_dir = CACHE_DIR

  dest_filename = _dest_filename(src_path, options, postfix)

  dest_path = File.join(dest_dir, dest_filename)
  dest_path_rel = File.join(CACHE_DIR, dest_filename)

  [src_path, dest_path, dest_dir, dest_filename, dest_path_rel]
end

# Determine whether the image needs to be written.
def _must_create?(src_path, dest_path)
  !File.exist?(dest_path) || File.mtime(dest_path) <= File.mtime(src_path)
end

#
# param source: e.g. "my-image.jpg"
# param options: e.g. "800x800>"
# param img_desc: e.g. "800x800>"
#
# return dest_path_rel: Relative path for output file.
def resize_gallery_image(img_src, options, postfix)
  raise "`source` must be a string - got: #{img_src.class}" unless img_src.is_a? String
  raise "`source` may not be empty" unless img_src.length > 0
  raise "`options` must be a string - got: #{options.class}" unless options.is_a? String
  raise "`options` may not be empty" unless options.length > 0

  src_path, dest_path, dest_dir, _, dest_path_rel = _paths(img_src, options, postfix)

  FileUtils.mkdir_p(dest_dir)

  if _must_create?(src_path, dest_path)
    puts "   Resizing '#{img_src}' to '#{dest_path_rel}' - using options: '#{options}'".green

    _process_img(src_path, options, dest_path)

  end

  dest_path_rel
end

# Processes the image: Annotate with custom graphic and shrink to the specified img_size
#
# param source: e.g. "my-image.jpg"
# param img_dim: e.g. "800x800"
# param dest_path: e.g. "my-image_800x800_lka34jks.jpg"
# param img_desc: e.g. "This is a cat!"
#
def _process_img(src_path, img_dim, dest_path)

  image = MiniMagick::Image.open(src_path)
  image = image.auto_orient

  image.strip
  image.resize img_dim
  image.format "webp"
  image.write dest_path

  # File permissions must be set if the format got changed.
  File.chmod(0644, dest_path)

  optimize(dest_path)

end

$imageoptim_options = YAML::load_file "_config.yml"
$imageoptim_options = $imageoptim_options["imageoptim"] || {}
$image_optim = ImageOptim.new $imageoptim_options

def optimize(image)
  puts "   Optimizing #{image}".green
  $image_optim.optimize_image! image
end

def split_params(params)
  params.split("::").map(&:strip)
end

def download_photos(config, uuid, site_context, tagged_with_webpage = true)

   files = DriveDownloader.list_files(config, uuid)

  optimized_img_paths = []

  semaphore = Mutex.new
  results = files.map do |file|
    next unless (file['mimeType'] == 'image/jpeg' or file['mimeType'] == 'image/png' or file['mimeType'] == 'image/heif')

    local_file_path = DriveDownloader.download_file(file, 'gallery', uuid[0, 10])

    # check if image should be displayed on webpage
    e = Exiftool.new(local_file_path)
    next unless ((tagged_with_webpage and e[:keywords].to_s.include?('Webpage')) or not tagged_with_webpage)

    path_1800x1200 = resize_gallery_image(local_file_path, '1800x1200', '')
    path_255x170 = resize_gallery_image(local_file_path, '255x170', '')

    optimized_img_paths.append path_1800x1200
    optimized_img_paths.append path_255x170

    image_size = ImageSize.path(path_1800x1200)
    landscape = image_size.width > image_size.height

    semaphore.synchronize {

      puts " - #{file['name']} (#{file['id']}, #{file['mimeType']})".green

      "<a href=\"{{ site.baseurl }}/#{path_1800x1200}\" data-cropped=\"true\" target=\"_blank\"
    data-pswp-width=\"#{image_size.width}\"  data-pswp-height=\"#{image_size.height}\" >
    <img #{
        if landscape then
          "class=\"landscape\""
        else
          ""
        end} loading=\"lazy\" src=\"{{ site.baseurl }}/#{path_255x170}\" alt=\"#{file['name'].gsub(/\.[^.]*\Z/, '')}\"/></a>"

    }
  end

  html_code = '<div class="gallery" id="gallery-simple">'
  html_code += results.join(" ")
  html_code += '</div>'

  # save the path of all site_context.static_files in an array
  static_files = []
  site_context.static_files.each do |file|
    static_files.append file.path
  end

  # Copy files to _site directory
  optimized_img_paths.each do |path|

    static_file = Jekyll::StaticFile.new(site_context, site_context.source, CACHE_DIR, File.basename(path))
    site_context.static_files << static_file unless static_files.include?(static_file.path)

  end

  return html_code

end

def gallery(config, gallery_settings, site)

  tagged = false
  if gallery_settings.include? " :: "
    gallery_settings = gallery_settings.split(" :: ")[0]
    tagged = true
  end

  html_code = download_photos(config, gallery_settings, site, tagged)

  "<div class=\"gallery-container\">
<script type=\"module\" src=\"{{ site.baseurl }}/script/gallery/gallery.js\"></script>
#{html_code}
</div>"

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ gallery (.*) \]\]/) do
      gallery(post.site.config, Regexp.last_match(1), post.site)
    end

  end
end