#!/usr/bin/env ruby
#
# Tests for bin/prune-unused-images.rb.
#
# This script deletes files, so the cases where it must *not* delete something
# are worth pinning down: an image whose name contains non-ASCII characters used
# to be treated as unreferenced and silently removed.
#
# Run with:  ruby test/prune-unused-images_test.rb

require 'fileutils'
require 'json'
require 'tmpdir'

SCRIPT = File.expand_path('../bin/prune-unused-images.rb', __dir__)

@failures = 0

def check(description)
  if yield
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    @failures += 1
  end
end

def with_fixture(html, cache_files)
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      FileUtils.mkdir_p('_site')
      File.write('_site/index.html', html)

      cache_files.each do |path|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, 'image data')
      end

      yield
    end
  end
end

puts 'referenced images survive, unreferenced ones are removed'
with_fixture(
  '<img src=/imgs/used_450x300.jpg><a href="/imgs/gallery/photo_255x170.webp"></a>',
  ['imgs/used_450x300.jpg', 'imgs/gallery/photo_255x170.webp', 'imgs/orphan_450x300.jpg']
) do
  system(RbConfig.ruby, SCRIPT, '_site', out: File::NULL)

  check('keeps an image referenced with an unquoted attribute') { File.exist?('imgs/used_450x300.jpg') }
  check('keeps an image referenced with a quoted attribute') { File.exist?('imgs/gallery/photo_255x170.webp') }
  check('removes an image nothing links to') { !File.exist?('imgs/orphan_450x300.jpg') }
end

puts 'non-ASCII file names are recognised'
with_fixture(
  '<img src=/imgs/stufe_fröschli_450x300.jpg><img src=/imgs/stufe_fr%C3%B6schli_600x400.jpg>',
  ['imgs/stufe_fröschli_450x300.jpg', 'imgs/stufe_fröschli_600x400.jpg']
) do
  system(RbConfig.ruby, SCRIPT, '_site', out: File::NULL)

  check('keeps a literal non-ASCII name') { File.exist?('imgs/stufe_fröschli_450x300.jpg') }
  check('keeps a percent-encoded non-ASCII name') { File.exist?('imgs/stufe_fröschli_600x400.jpg') }
end

puts 'a build with no images at all is treated as suspicious'
with_fixture('<p>no images here</p>', ['imgs/something_450x300.jpg']) do
  system(RbConfig.ruby, SCRIPT, '_site', out: File::NULL, err: File::NULL)

  check('deletes nothing when the site references no images') { File.exist?('imgs/something_450x300.jpg') }
end

puts 'the copy in _site is removed alongside the cached original'
with_fixture('<img src=/imgs/used_450x300.jpg>', ['imgs/used_450x300.jpg', 'imgs/orphan_450x300.jpg']) do
  FileUtils.mkdir_p('_site/imgs')
  File.write('_site/imgs/orphan_450x300.jpg', 'image data')

  system(RbConfig.ruby, SCRIPT, '_site', out: File::NULL)

  check('removes the published copy too') { !File.exist?('_site/imgs/orphan_450x300.jpg') }
end

puts 'the manifest forgets pruned entries'
with_fixture('<img src=/imgs/used_450x300.jpg>', ['imgs/used_450x300.jpg', 'imgs/orphan_450x300.jpg']) do
  File.write('imgs/.derivatives.json', JSON.generate(
    'version' => 1,
    'derivatives' => { 'imgs/used_450x300.jpg' => 'sha1:aaa', 'imgs/orphan_450x300.jpg' => 'sha1:bbb' },
    'drive' => {
      'drive:kept:1' => { 'included' => true, 'paths' => ['imgs/used_450x300.jpg'] },
      'drive:gone:1' => { 'included' => true, 'paths' => ['imgs/orphan_450x300.jpg'] },
      'drive:untagged:1' => { 'included' => false, 'paths' => [] }
    }
  ))

  system(RbConfig.ruby, SCRIPT, '_site', out: File::NULL)
  manifest = JSON.parse(File.read('imgs/.derivatives.json'))

  check('drops the pruned derivative') { !manifest['derivatives'].key?('imgs/orphan_450x300.jpg') }
  check('keeps the surviving derivative') { manifest['derivatives'].key?('imgs/used_450x300.jpg') }
  check('drops the Drive entry whose images are gone') { !manifest['drive'].key?('drive:gone:1') }
  check('keeps the Drive entry whose images survive') { manifest['drive'].key?('drive:kept:1') }
  check('keeps photos known to be untagged, so they are not downloaded again') do
    manifest['drive'].key?('drive:untagged:1')
  end
end

puts @failures.zero? ? 'All checks passed.' : "#{@failures} check(s) failed."
exit(@failures.zero? ? 0 : 1)
