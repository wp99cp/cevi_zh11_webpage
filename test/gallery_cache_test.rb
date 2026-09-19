#!/usr/bin/env ruby
#
# Tests the caching and invalidation of the Google Drive gallery.
#
# CI is the only place with Drive credentials, so this stubs the Drive API out
# and drives _plugins/gallery.rb against a fake folder. What is being pinned down
# is the behaviour that decides both how fast the build is and whether the page
# is correct:
#
#   * an unchanged photo is not downloaded again
#   * a photo edited in Drive is
#   * a photo deleted in Drive disappears from the page
#   * a photo without the 'Webpage' keyword is not downloaded again either
#
# Run with:  ruby test/gallery_cache_test.rb

require 'fileutils'
require 'tmpdir'
require 'json'

require 'jekyll'
require 'mini_magick'
require 'image_size'
require 'colorator'

@failures = 0

def check(description)
  if yield
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    @failures += 1
  end
end

FIXTURE_ROOT = Dir.mktmpdir
SOURCE_PHOTO = File.join(FIXTURE_ROOT, 'source.jpg')
system('convert', '-size', '1200x900', 'plasma:fractal', SOURCE_PHOTO, exception: true)

# The plugin is loaded first so that the stubs below override the real
# DriveDownloader and Exiftool rather than the other way round.
require_relative '../_plugins/utils/derivative_cache'
require_relative '../_plugins/gallery.rb'

# Stands in for the Drive API. Records every download so the tests can assert
# that the cache actually prevented one.
module DriveDownloader

  class << self
    attr_accessor :files, :downloads, :keywords

    def list_files(_config, _folder_id)
      files
    end

    def available?
      true
    end

    def local_path_for(file, directory, prefix = '')
      # Mirrors DriveDownloader.parse_file_name: spaces become underscores.
      name = file['name'].sub(/\.[^.]*\z/, '').gsub(/\s/, '_')
      File.join(directory, "#{prefix}#{name}.jpg")
    end

    def download_file(file, directory, prefix = '')
      path = local_path_for(file, directory, prefix)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.cp(SOURCE_PHOTO, path)
      downloads << file['id']
      path
    end
  end

  self.files = []
  self.downloads = []
  self.keywords = {}

end

# Stands in for exiftool, which would need a real photo with real IPTC keywords.
class Exiftool
  def initialize(path)
    @path = path
  end

  def [](field)
    return nil unless field == :keywords

    # The downloaded file carries the gallery id as a prefix, so match on the
    # tail of the name rather than on the whole thing.
    basename = File.basename(@path, '.*')
    _, keywords = DriveDownloader.keywords.find { |name, _| basename.end_with?(name) }

    keywords || 'Webpage'
  end
end

FOLDER = 'testfolderid1234567'

def drive_file(id, name, modified)
  { 'id' => id, 'name' => name, 'mimeType' => 'image/jpeg', 'modifiedTime' => modified }
end

def build_gallery(tagged: false)
  DriveDownloader.downloads = []
  generate_gallery_html({}, FOLDER, nil, tagged)
end

Dir.mktmpdir do |dir|
  Dir.chdir(dir) do

    DriveDownloader.files = [
      drive_file('photo-a', 'a.jpg', '2026-01-01T00:00:00Z'),
      drive_file('photo-b', 'b.jpg', '2026-01-01T00:00:00Z')
    ]

    puts 'first build downloads and converts every photo'
    html = build_gallery
    check('downloads both photos') { DriveDownloader.downloads.sort == %w[photo-a photo-b] }
    check('both photos appear on the page') { html.scan('<a href=').length == 2 }
    check('writes the large and the thumbnail version') do
      Dir.glob('imgs/gallery/*.webp').length == 4
    end
    check('deletes the downloaded original') { Dir.glob('gallery/*').empty? }

    first_html = html

    puts 'second build reuses everything and touches the network for nothing'
    html = build_gallery
    check('downloads nothing') { DriveDownloader.downloads.empty? }
    check('produces exactly the same markup') { html == first_html }

    puts 'a photo edited in Drive is rebuilt'
    DriveDownloader.files[0] = drive_file('photo-a', 'a.jpg', '2026-06-01T00:00:00Z')
    build_gallery
    check('downloads only the edited photo') { DriveDownloader.downloads == ['photo-a'] }

    puts 'a photo deleted in Drive disappears from the page'
    DriveDownloader.files = [drive_file('photo-b', 'b.jpg', '2026-01-01T00:00:00Z')]
    html = build_gallery
    check('downloads nothing') { DriveDownloader.downloads.empty? }
    check('only the surviving photo is linked') { html.scan('<a href=').length == 1 }
    check('the deleted photo is no longer referenced') { !html.include?('a_1800x1200') }

    puts 'two photos that share a file name are kept apart'
    DriveDownloader.files = [
      drive_file('photo-d', 'Kopie von X.jpg', '2026-01-01T00:00:00Z'),
      drive_file('photo-e', 'Kopie von X.jpg', '2026-01-01T00:00:00Z')
    ]
    html = build_gallery
    check('downloads both of them') { DriveDownloader.downloads.sort == %w[photo-d photo-e] }
    check('gives them separate images') do
      html.scan(%r{imgs/gallery/\S+_1800x1200\.webp}).uniq.length == 2
    end
    check('both appear on the page') { html.scan('<a href=').length == 2 }

    puts 'a photo without the Webpage keyword is skipped, and stays skipped'
    DriveDownloader.files = [
      drive_file('photo-b', 'b.jpg', '2026-01-01T00:00:00Z'),
      drive_file('photo-c', 'c.jpg', '2026-01-01T00:00:00Z')
    ]
    DriveDownloader.keywords = { 'c' => 'Holiday' }

    html = build_gallery(tagged: true)
    check('downloads the untagged photo once to read its keywords') do
      DriveDownloader.downloads.include?('photo-c')
    end
    check('leaves it off the page') { !html.include?('c_1800x1200') }

    build_gallery(tagged: true)
    check('does not download it again on the next build') do
      !DriveDownloader.downloads.include?('photo-c')
    end

  end
end

FileUtils.remove_entry(FIXTURE_ROOT)

puts @failures.zero? ? 'All checks passed.' : "#{@failures} check(s) failed."
exit(@failures.zero? ? 0 : 1)
