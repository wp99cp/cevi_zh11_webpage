#!/usr/bin/env ruby
#
# Tests reusing the images already published on the live site.
#
# The risk this guards against is serving a stale photo: the file names do not
# change when a photo is replaced in Drive, so fetching by name alone would
# happily pick up the previous version and record it as current. Reuse is
# therefore only allowed when the published index agrees about which input the
# file was built from.
#
# Run with:  ruby test/remote_derivatives_test.rb

require 'fileutils'
require 'json'
require 'tmpdir'
require 'webrick'

require 'colorator'

require_relative '../_plugins/utils/remote_derivatives'

@failures = 0

def check(description)
  if yield
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    @failures += 1
  end
end

PUBLISHED = Dir.mktmpdir
FileUtils.mkdir_p(File.join(PUBLISHED, 'imgs'))
File.write(File.join(PUBLISHED, 'imgs', 'photo_255x170.webp'), 'published image bytes')
File.write(File.join(PUBLISHED, 'imgs', 'derivatives-index.json'), JSON.generate(
  'version' => 1,
  'entries' => { 'imgs/photo_255x170.webp' => RemoteDerivatives.digest('drive:photo:v1') },
  'photos' => {
    RemoteDerivatives.digest('drive:photo:v1') => {
      'included' => true, 'paths' => ['imgs/photo_255x170.webp'], 'width' => 1800, 'height' => 1200
    }
  }
))

server = WEBrick::HTTPServer.new(
  Port: 0, DocumentRoot: PUBLISHED,
  Logger: WEBrick::Log.new(File::NULL), AccessLog: []
)
Thread.new { server.start }
ENV['DERIVATIVES_BASE_URL'] = "http://127.0.0.1:#{server.config[:Port]}"

begin
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do

      puts 'an image built from the same input is reused'
      restored = RemoteDerivatives.fetch('imgs/photo_255x170.webp', 'drive:photo:v1', 'imgs/photo_255x170.webp')
      check('reports that it fetched the file') { restored }
      check('writes the published bytes') do
        File.exist?('imgs/photo_255x170.webp') && File.read('imgs/photo_255x170.webp') == 'published image bytes'
      end

      puts 'an image whose photo was replaced in Drive is not reused'
      FileUtils.rm_f('imgs/photo_255x170.webp')
      restored = RemoteDerivatives.fetch('imgs/photo_255x170.webp', 'drive:photo:v2', 'imgs/photo_255x170.webp')
      check('refuses the stale published copy') { !restored }
      check('leaves nothing behind to be mistaken for current') { !File.exist?('imgs/photo_255x170.webp') }

      puts 'an image the live site has never heard of is not reused'
      restored = RemoteDerivatives.fetch('imgs/unknown_255x170.webp', 'sha1:whatever', 'imgs/unknown_255x170.webp')
      check('reports nothing fetched') { !restored }

      puts 'photo metadata is taken from the published index'
      check('finds the entry for a matching key') { RemoteDerivatives.photo('drive:photo:v1')['width'] == 1800 }
      check('finds nothing for a changed key') { RemoteDerivatives.photo('drive:photo:v2').nil? }

      puts 'the index this build publishes can be read back'
      index = RemoteDerivatives.build_index(
        { 'imgs/a_450x300.jpg' => 'sha1:abc' },
        { 'drive:x:1' => { 'included' => false, 'paths' => [] } }
      )
      check('keys images by a digest, never by the raw cache key') do
        index['entries']['imgs/a_450x300.jpg'] == RemoteDerivatives.digest('sha1:abc')
      end
      check('does not leak Google Drive ids') { !JSON.generate(index).include?('drive:x:1') }

    end
  end
ensure
  server.shutdown
  FileUtils.remove_entry(PUBLISHED)
end

puts @failures.zero? ? 'All checks passed.' : "#{@failures} check(s) failed."
exit(@failures.zero? ? 0 : 1)
