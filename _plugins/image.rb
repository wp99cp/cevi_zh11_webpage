# Based on https://github.com/MichaelCurrin/jekyll-resize
require "digest"
require "mini_magick"

require 'yaml'
require "image_optim"
require "image_optim_pack"

class ImageInlineTag < Liquid::Tag

  def initialize(tag_name, input, tokens)
    super
    @input = input

    imageoptim_options = YAML::load_file "_config.yml"
    @imageoptim_options = imageoptim_options["imageoptim"] || {}

    @image_optim = ImageOptim.new @imageoptim_options

  end

  CACHE_DIR = "imgs/"
  HASH_LENGTH = 32

  # Generate output image filename.
  def _dest_filename(src_path, options, dest_dir)
    hash = Digest::SHA256.file(src_path)
    short_hash = hash.hexdigest()[0, HASH_LENGTH]
    options_slug = options.gsub(/[^\da-z]+/i, "")
    ext = File.extname(src_path)

    "#{File.basename(src_path, ".*")}_#{options_slug}#{ext}"
  end

  # Build the path strings.
  def _paths(repo_base, img_path, options)

    src_path = File.join(repo_base, img_path)
    raise "Image at #{src_path} is not readable" unless File.readable?(src_path)

    dest_dir = File.join(repo_base, CACHE_DIR)

    dest_filename = _dest_filename(src_path, options, dest_dir)

    dest_path = File.join(dest_dir, dest_filename)
    dest_path_rel = File.join(CACHE_DIR, dest_filename)

    return src_path, dest_path, dest_dir, dest_filename, dest_path_rel
  end

  # Determine whether the image needs to be written.
  def _must_create?(src_path, dest_path)
    !File.exist?(dest_path) || File.mtime(dest_path) <= File.mtime(src_path)
  end

  # Read, process, and write out as new image.
  def _process_img(src_path, options, dest_path)
    image = MiniMagick::Image.open(src_path)

    image.strip
    image.resize options

    image.write dest_path

    optimize(dest_path)

  end

  def optimize(image)
    puts "Optimizing #{image}".green
    @image_optim.optimize_image! image
  end

  # Liquid tag entry-point.
  #
  # param source: e.g. "my-image.jpg"
  # param options: e.g. "800x800>"
  #
  # return dest_path_rel: Relative path for output file.
  def resize(source, options)
    raise "`source` must be a string - got: #{source.class}" unless source.is_a? String
    raise "`source` may not be empty" unless source.length > 0
    raise "`options` must be a string - got: #{options.class}" unless options.is_a? String
    raise "`options` may not be empty" unless options.length > 0

    site = @context.registers[:site]

    src_path, dest_path, dest_dir, dest_filename, dest_path_rel = _paths(site.source, source, options)

    FileUtils.mkdir_p(dest_dir)

    if _must_create?(src_path, dest_path)
      puts "Resizing '#{source}' to '#{dest_path_rel}' - using options: '#{options}'"

      _process_img(src_path, options, dest_path)

      site.static_files << Jekyll::StaticFile.new(site, site.source, CACHE_DIR, dest_filename)
    end

    File.join(site.baseurl, dest_path_rel)
  end

  def split_params(params)
    params.split("::").map(&:strip)
  end

  def render(context)

    args = split_params(@input)
    raise "Wrong number of arguments" unless args.length == 3

    @context = context
    path_1800x1200 = resize(args[0], '1800x1200')
    path_1200x800 = resize(args[0], '1200x800')
    path_1125x750 = resize(args[0], '1125x750')
    path_600x400 = resize(args[0], '600x400')
    path_450x300 = resize(args[0], '450x300')

    # Write the output HTML string
    output = "<figure>
                <img src=\"#{ path_1800x1200 }\" alt=\"#{ args[1] }\"
                     srcset=\" #{path_1800x1200} 1800w, #{path_1200x800} 1200w,
                               #{path_1125x750} 1125w,  #{path_600x400} 600w,
                               #{path_450x300} 450w \"/>
                <span> #{ args[2] } </span>
              </figure>"

    # Render it on the page by returning it
    return output;
  end

end

Liquid::Template.register_tag('image', ImageInlineTag)