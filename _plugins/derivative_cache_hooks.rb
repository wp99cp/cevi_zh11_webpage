require 'set'

require_relative 'utils/derivative_cache'
require_relative 'utils/build_stats'

# Make sure every generated image the page actually links to ends up in _site.
#
# responsive-images-for-jekyll only registers a static file in the branch where
# it *creates* the image, so now that the cache works, images that were reused
# rather than regenerated would silently be missing from the output.
Jekyll::Hooks.register :site, :post_render do |site|

  known = site.static_files.map(&:path).to_set

  DerivativeCache.referenced_paths.each do |path|
    # Jekyll stats every static file it is given, so one that does not exist
    # brings the whole build down. Skipping is safer than trusting the callers:
    # a missing image is a page with a broken <img>, not a failed deploy.
    next unless File.file?(path)

    static_file = Jekyll::StaticFile.new(site, site.source, File.dirname(path), File.basename(path))
    site.static_files << static_file unless known.include?(static_file.path)
  end

end

Jekyll::Hooks.register :site, :post_write do |_site|
  DerivativeCache.save!

  # The site is built twice, each pass in its own process, so the numbers are
  # accumulated on disk and reported once both passes are done.
  BuildStats.flush!
end
