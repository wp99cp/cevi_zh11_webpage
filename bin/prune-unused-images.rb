#!/usr/bin/env ruby
#
# Removes generated images that the built site no longer links to.
#
# imgs/ is a build cache that survives between CI runs, and Jekyll copies it into
# _site wholesale. Without this step, the resized version of a photo that was
# deleted in Google Drive - or of a picture that was removed from a page - stays
# in the cache forever and keeps being published.
#
# The set of images that are still needed is taken from the generated output
# rather than from the build's own bookkeeping, because `jekyll build
# --incremental` does not re-render unchanged pages, so their images never pass
# through the plugins on a second build. Reading _site instead is immune to that.
#
# Must only run after a *complete* build; docker-entrypoint.sh aborts on the
# first failure, so reaching this point means both build passes succeeded.

require 'cgi'
require 'json'
require 'set'

SITE_DIR = ARGV[0] || '_site'
CACHE_DIR = 'imgs'
MANIFEST = File.join(CACHE_DIR, '.derivatives.json')

# Files under imgs/ that are not derivatives: scratch space, and the index that
# lets the next build reuse the images published on the live site.
KEEP = Set['imgs/annotation.svg', 'imgs/derivatives-index.json']

# Any text file in the output may link to an image, not just HTML: stylesheets
# use url(), the gallery script and the sitemap carry paths too.
SCANNED_EXTENSIONS = %w[.html .htm .css .js .json .xml .txt .svg].freeze

# Matches a path into imgs/ up to its file extension. Deliberately not written
# with \w: file names such as stufe_fröschli.jpg contain non-ASCII characters,
# which \w does not match, and every one of those images would look unused.
IMAGE_REFERENCE = %r{imgs/[^\s"'<>()\[\]{},\\]*?\.(?:jpe?g|png|webp|gif|svg|avif)}i

abort "#{SITE_DIR} does not exist - refusing to prune." unless Dir.exist?(SITE_DIR)
exit 0 unless Dir.exist?(CACHE_DIR)

referenced = Set.new

Dir.glob(File.join(SITE_DIR, '**', '*')).each do |path|
  next unless File.file?(path)
  next unless SCANNED_EXTENSIONS.include?(File.extname(path).downcase)

  contents = File.read(path, encoding: 'UTF-8', invalid: :replace, undef: :replace)

  contents.scan(IMAGE_REFERENCE) do |match|
    referenced << match
    # Links may also be percent-encoded, e.g. stufe_fr%C3%B6schli.jpg
    referenced << CGI.unescape(match)
  end
end

# A build that produced no image references at all is not a site with no images,
# it is a build that went wrong in a way that did not raise.
if referenced.empty?
  warn 'No image references found in the built site - skipping cleanup.'
  exit 0
end

removed = []

Dir.glob(File.join(CACHE_DIR, '**', '*')).each do |path|
  next unless File.file?(path)
  next if path == MANIFEST
  next if KEEP.include?(path)
  next if referenced.include?(path)

  File.delete(path)

  mirrored = File.join(SITE_DIR, path)
  File.delete(mirrored) if File.file?(mirrored)

  removed << path
end

# Forget the pruned files, so the manifest does not grow without bound either.
if File.exist?(MANIFEST)
  begin
    manifest = JSON.parse(File.read(MANIFEST))
    manifest['derivatives'] = (manifest['derivatives'] || {}).select { |dest, _| referenced.include?(dest) }
    kept_paths = Set.new(manifest['derivatives'].keys)
    manifest['drive'] = (manifest['drive'] || {}).select do |_, entry|
      paths = Array(entry['paths'])
      # Photos that are not tagged for the webpage have no derivatives; keeping
      # them is what stops us from downloading them again on the next build.
      paths.empty? || paths.all? { |p| kept_paths.include?(p) }
    end
    File.write(MANIFEST, JSON.pretty_generate(manifest))
  rescue JSON::ParserError => e
    warn "Could not update #{MANIFEST}: #{e.message}"
  end
end

puts "Removed #{removed.length} unused image(s) from #{CACHE_DIR}." unless removed.empty?
