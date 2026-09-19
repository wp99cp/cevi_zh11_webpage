require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'
require 'benchmark'
require_relative 'utils/drive_downloader'
require_relative 'utils/derivative_cache'
require 'exiftool'
require 'parallel'
require 'digest/sha1'

def date_to_string(timestamp)

  return '' if timestamp.nil?
  DateTime.parse(timestamp.to_s).strftime('%d.%m.%Y').to_s

end

CACHE_DIR = "imgs/gallery"

# Photos are downloaded and converted independently of each other, so they can
# run concurrently. Both halves of the work release the GIL - downloading waits
# on the network, converting waits on an ImageMagick subprocess - so threads are
# enough and we avoid marshalling results back from forked processes.
GALLERY_CONCURRENCY = (ENV['GALLERY_CONCURRENCY'] || 8).to_i

# Generate output image filename.
def _dest_filename(src_path, options, postfix)

  options_slug = options.gsub(/[^\da-z]+/i, "")
  ext = '.webp' # File.extname(src_path)

  "#{File.basename(src_path, ".*")}_#{options_slug}#{"_" unless postfix == ''}#{postfix}#{ext}"

end

# Build the path strings.
def _paths(img_path, options, postfix)

  src_path = img_path

  dest_dir = CACHE_DIR

  dest_filename = _dest_filename(src_path, options, postfix)

  dest_path = File.join(dest_dir, dest_filename)
  dest_path_rel = File.join(CACHE_DIR, dest_filename)

  [src_path, dest_path, dest_dir, dest_filename, dest_path_rel]
end

#
# param source: e.g. "my-image.jpg"
# param options: e.g. "800x800>"
# param img_desc: e.g. "800x800>"
# param key: cache key of the input, defaults to a hash of the source file
#
# return dest_path_rel: Relative path for output file.
def resize_gallery_image(img_src, options, postfix, key = nil)
  raise "`source` must be a string - got: #{img_src.class}" unless img_src.is_a? String
  raise "`source` may not be empty" unless img_src.length > 0
  raise "`options` must be a string - got: #{options.class}" unless options.is_a? String
  raise "`options` may not be empty" unless options.length > 0

  src_path, dest_path, dest_dir, _, dest_path_rel = _paths(img_src, options, postfix)

  DerivativeCache.reference(dest_path)

  if key.nil?
    raise "Image at #{src_path} is not readable" unless File.readable?(src_path)
    key = DerivativeCache.source_key(src_path)
  end

  return dest_path_rel if DerivativeCache.fresh?(dest_path, key)

  raise "Image at #{src_path} is not readable" unless File.readable?(src_path)

  FileUtils.mkdir_p(dest_dir)

  puts "   Resizing '#{img_src} - using options: '#{options}'".green
  _process_img(src_path, [[options, dest_path]])

  DerivativeCache.record(dest_path, key)

  dest_path_rel
end

# Converts one source image into one or more sizes.
#
# param src_path: e.g. "my-image.jpg"
# param outputs: e.g. [["1800x1200", "a.webp"], ["255x170", "b.webp"]]
#
def _process_img(src_path, outputs)

  # A single ImageMagick invocation that decodes the source once and writes every
  # size from a clone of it.
  #
  # Applying the operations in-place instead (MiniMagick::Image#auto_orient,
  # #strip, #resize) re-encodes the *source* format after every step, which for
  # the HEIC photos coming from Google Drive costs ~9s per step and is thrown
  # away anyway. Each size is resized from its own clone rather than from the
  # previous output, so the results are byte for byte what one convert per size
  # produced. "[0]" picks the first frame, matching what MiniMagick::Image#format
  # did.
  MiniMagick::Tool::Convert.new do |convert|
    convert << "#{src_path}[0]"
    convert.auto_orient
    convert.strip

    outputs.each do |(img_dim, dest_path)|
      convert << '(' << '+clone'
      convert.resize img_dim
      convert.write dest_path
      convert << '+delete' << ')'
    end

    convert << 'null:'
  end

  # File permissions must be set if the format got changed.
  outputs.each { |(_, dest_path)| File.chmod(0644, dest_path) }

  # image_optim only ships workers for jpeg, png and gif, so running it over the
  # webp files we write here did nothing except spawn a process per image.

end

def split_params(params)
  params.split("::").map(&:strip)
end

GALLERY_MIME_TYPES = %w[image/jpeg image/png image/heif].freeze

# Produces the <a>...</a> snippet for a single photo, reusing the cached
# derivatives when the photo has not changed in Drive since we last saw it.
def _gallery_entry(file, uuid, tagged_with_webpage)

  key = DerivativeCache.drive_key(file)
  local_file_path = DriveDownloader.local_path_for(file, 'gallery', uuid[0, 10] + '_')

  _, path_1800x1200, = _paths(local_file_path, '1800x1200', '')
  _, path_255x170, = _paths(local_file_path, '255x170', '')

  DerivativeCache.reference(path_1800x1200)
  DerivativeCache.reference(path_255x170)
  DerivativeCache.reference_drive(key)

  cached = DerivativeCache.drive_entry(key)

  if cached
    # The photo is not tagged for the webpage. Remembering that is what keeps us
    # from downloading it again on every build just to re-read its keywords.
    return nil unless cached['included']

    # Everything we need is already available: no download, no EXIF read, no
    # resize. The images may have come from the live site rather than from the
    # local cache, so write the entry back either way.
    if DerivativeCache.fresh?(path_1800x1200, key) && DerivativeCache.fresh?(path_255x170, key)
      puts " - File #{file['name']} is unchanged, reusing cached images...".green
      DerivativeCache.record_drive(key, cached)
      return _gallery_html(file, path_1800x1200, path_255x170, cached['width'], cached['height'])
    end
  end

  downloaded_path = DriveDownloader.download_file(file, 'gallery', uuid[0, 10] + '_')
  return nil if downloaded_path.nil?

  begin
    # check if image should be displayed on webpage
    included = true
    if tagged_with_webpage
      included = Exiftool.new(downloaded_path)[:keywords].to_s.include?('Webpage')
    end

    unless included
      DerivativeCache.record_drive(key, { 'included' => false, 'paths' => [] })
      return nil
    end

    puts "   Resizing '#{downloaded_path}'".green
    FileUtils.mkdir_p(CACHE_DIR)
    _process_img(downloaded_path, [['1800x1200', path_1800x1200], ['255x170', path_255x170]])

    DerivativeCache.record(path_1800x1200, key)
    DerivativeCache.record(path_255x170, key)

    image_size = ImageSize.path(path_1800x1200)
    DerivativeCache.record_drive(key, {
      'included' => true,
      'paths' => [path_1800x1200, path_255x170],
      'width' => image_size.width,
      'height' => image_size.height
    })

    _gallery_html(file, path_1800x1200, path_255x170, image_size.width, image_size.height)
  ensure
    # The original is several MB and is only ever needed to produce the two
    # derivatives above.
    File.delete(downloaded_path) if File.exist?(downloaded_path)
  end

end

def _gallery_html(file, path_1800x1200, path_255x170, width, height)

  landscape = width > height

  "<a href=\"{{ site.baseurl }}/#{path_1800x1200}\" data-cropped=\"true\" target=\"_blank\"
    data-pswp-width=\"#{width}\"  data-pswp-height=\"#{height}\" >
    <img #{
    if landscape then
      "class=\"landscape\""
    else
      ""
    end} loading=\"lazy\" src=\"{{ site.baseurl }}/#{path_255x170}\" alt=\"#{file['name'].gsub(/\.[^.]*\Z/, '')}\"/></a>"

end

def generate_gallery_html(config, uuid, site_context, tagged_with_webpage = true)

  files = DriveDownloader.list_files(config, uuid)
  puts "Found #{files.length} files in gallery #{uuid}.".blue

  candidates = files.select { |file| GALLERY_MIME_TYPES.include?(file['mimeType']) }

  results = Parallel.map(candidates, in_threads: GALLERY_CONCURRENCY) do |file|
    _gallery_entry(file, uuid, tagged_with_webpage)
  end

  html_code = '<div class="gallery" id="gallery-simple">'
  html_code += results.compact.join(" ")
  html_code += '</div>'

  html_code

end

def gallery(config, gallery_settings, site)

  tagged = false
  if gallery_settings.include? " :: "
    gallery_settings = gallery_settings.split(" :: ")[0]
    tagged = true
  end

  html_code = generate_gallery_html(config, gallery_settings, site, tagged)

  "
  <div class=\"gallery-container\">
    <script type=\"module\" src=\"{{ site.baseurl }}/script/gallery/gallery.js\"></script>
    #{html_code}
  </div>
  "

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
