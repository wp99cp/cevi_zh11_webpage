require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'

def parse_file_name(file_name)

  file_name = file_name.gsub(/\s/, '_')
  file_name.gsub(/\.[^.]*\Z/, '')

end

def date_to_string(timestamp)

  return '' if timestamp.nil?
  DateTime.parse(timestamp.to_s).strftime('%d.%m.%Y').to_s

end

def download_photo(drive_service, file)

  directory = 'gallery'
  file_name = parse_file_name(file.name)
  file_path = File.join(directory, file_name)
  file_path += '.jpg'

  if File.file?(file_path.to_s)
    puts 'File is cached'
    return file_path
  end

  FileUtils.mkdir_p directory unless File.directory?(directory)

  puts "Download file: #{file_path}"
  drive_service.get_file(file.id, download_dest: file_path, supports_all_drives: true)
  file_path

end

CACHE_DIR = "imgs/gallery"

# Generate output image filename.
def _dest_filename(src_path, options)

  options_slug = options.gsub(/[^\da-z]+/i, "")
  ext = File.extname(src_path)

  "#{File.basename(src_path, ".*")}_#{options_slug}#{ext}"

end

# Build the path strings.
def _paths(img_path, options)

  src_path = img_path
  raise "Image at #{src_path} is not readable" unless File.readable?(src_path)

  dest_dir = CACHE_DIR

  dest_filename = _dest_filename(src_path, options)

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
def resize_gallery_image(img_src, options)
  raise "`source` must be a string - got: #{img_src.class}" unless img_src.is_a? String
  raise "`source` may not be empty" unless img_src.length > 0
  raise "`options` must be a string - got: #{options.class}" unless options.is_a? String
  raise "`options` may not be empty" unless options.length > 0

  src_path, dest_path, dest_dir, _, dest_path_rel = _paths(img_src, options)

  FileUtils.mkdir_p(dest_dir)

  if _must_create?(src_path, dest_path)
    puts "Resizing '#{img_src}' to '#{dest_path_rel}' - using options: '#{options}'"

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

  image.strip
  image.resize img_dim
  image.write dest_path

  optimize(dest_path)

end

$imageoptim_options = YAML::load_file "_config.yml"
$imageoptim_options = $imageoptim_options["imageoptim"] || {}
$image_optim = ImageOptim.new $imageoptim_options

def optimize(image)
  puts "Optimizing #{image}".green
  $image_optim.optimize_image! image
end

def split_params(params)
  params.split("::").map(&:strip)
end

def download_photos(uuid, site_context)

  credentials = '_secrets/credentials.json'
  scope = 'https://www.googleapis.com/auth/drive.readonly'

  authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(credentials), scope: scope
  )

  Google::Apis::RequestOptions.default.retries = 5

  drive_service = Google::Apis::DriveV3::DriveService.new
  drive_service.authorization = authorizer
  drive_service.client_options.send_timeout_sec=12000
  drive_service.client_options.open_timeout_sec=12000
  drive_service.client_options.read_timeout_sec=12000

  puts uuid

  folder_id = uuid
  query = "parents = '#{folder_id}'"
  fields = 'nextPageToken, files(id, name, mimeType, size, parents, modifiedTime)'

  response = drive_service.list_files(q: query, supports_all_drives: true, corpora: 'allDrives',
                                      include_items_from_all_drives: true, fields: fields)

  puts 'No files found' if response.files.empty?

  html_code = '<div class="gallery" id="gallery-simple">'

  optimized_img_paths = []

  response.files.each do |file|
    puts "#{file.name} (#{file.id}, #{file.mime_type})"
    next unless file.mime_type == 'image/jpeg'

    full_file_name = download_photo(drive_service, file)

    path_1800x1200 = resize_gallery_image(full_file_name, '1800x1200')
    path_255x170 = resize_gallery_image(full_file_name, '255x170')

    optimized_img_paths.append path_1800x1200
    optimized_img_paths.append path_255x170

    html_code += "<a href=\"#{path_1800x1200}\" data-cropped=\"true\" target=\"_blank\"
    data-pswp-width=\"1800\"  data-pswp-height=\"1200\" >
    <img loading=\"lazy\" src=\"#{path_255x170}\" alt=\"#{file.name.gsub(/\.[^.]*\Z/, '')}\"/></a>"

    puts full_file_name

  end

  html_code += '</div>'

  # Copy files to _site directory
  optimized_img_paths.each do |path|
    site_context.static_files << Jekyll::StaticFile.new(site_context, site_context.source, CACHE_DIR, File.basename(path))
  end

  html_code

end

def gallery(path, site)

  html_code = download_photos(path, site)

  "<div>
<link rel=\"stylesheet\" href=\"/_template_assets/foto_gallery.css\"/>
<script type=\"module\" src=\"script/gallery/gallery.js\"></script>
#{html_code}
</div>"

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ gallery (.*) \]\]/) do
      gallery(Regexp.last_match(1), post.site)
    end

  end
end