require 'json'
require 'digest'
require 'fileutils'

require_relative 'remote_derivatives'

# Tracks which generated images under imgs/ are still up to date.
#
# The plugins used to decide this by comparing mtimes:
#
#   File.mtime(dest_path) <= File.mtime(src_path)
#
# which can never be true in CI. actions/checkout stamps every source file with
# the time of the checkout, while actions/cache restores the generated images
# with the (older) mtimes they had when they were written. Every image therefore
# looked stale and the whole cache was rebuilt from scratch on every single run.
#
# Instead we remember, for each generated file, a key describing the input it was
# made from: a SHA1 of the file contents for images in the repo, and Drive's file
# id plus modifiedTime for gallery photos. Comparing keys does not depend on
# mtimes, so a fresh checkout no longer invalidates anything, and a genuinely
# changed input still does.
module DerivativeCache

  MANIFEST_PATH = 'imgs/.derivatives.json'.freeze
  VERSION = 1

  # Files under imgs/ that are written as scratch space rather than as a
  # derivative, and must survive pruning.
  SCRATCH_FILES = ['imgs/annotation.svg', RemoteDerivatives::INDEX_PATH].freeze

  @mutex = Mutex.new
  @manifest = nil
  @source_keys = {}
  @referenced = {}
  @referenced_drive = {}

  class << self

    # The plugins hand us a mix of absolute and repo-relative paths; the manifest
    # only ever stores repo-relative ones so that it survives being restored into
    # a different checkout directory.
    def relative(path)
      path.delete_prefix(Dir.pwd + File::SEPARATOR)
    end

    # Key for a file that lives in the repository: its content hash. Memoised,
    # because every source is resized into five different sizes and hashing the
    # larger photos repeatedly is not free.
    def source_key(src_path)
      @mutex.synchronize do
        @source_keys[src_path] ||= "sha1:#{Digest::SHA1.file(src_path).hexdigest}"
      end
    end

    # Key for a photo that lives in Google Drive. modifiedTime changes whenever
    # the photo is replaced or its metadata (e.g. the 'Webpage' keyword) is
    # edited, which is exactly when the derivatives need to be rebuilt.
    def drive_key(file)
      "drive:#{file['id']}:#{file['modifiedTime']}"
    end

    def fresh?(dest_path, key)
      path = relative(dest_path)

      return true if @mutex.synchronize { manifest['derivatives'][path] == key } && File.exist?(dest_path)

      # Nothing usable on disk - the live site may still have it.
      return false unless RemoteDerivatives.fetch(path, key, dest_path)

      record(dest_path, key)
      true
    end

    def record(dest_path, key)
      @mutex.synchronize { manifest['derivatives'][relative(dest_path)] = key }
    end

    # Per-Drive-photo bookkeeping, so that an unchanged photo does not have to be
    # downloaded again just to re-read its EXIF keywords and dimensions.
    def drive_entry(key)
      @mutex.synchronize { manifest['drive'][key] } || RemoteDerivatives.photo(key)
    end

    def record_drive(key, entry)
      @mutex.synchronize { manifest['drive'][key] = entry }
    end

    def reference_drive(key)
      @mutex.synchronize { @referenced_drive[key] = true }
    end

    # Mark a generated file as still in use by this build. Anything under imgs/
    # that is never referenced belonged to a page or a Drive photo that no longer
    # exists, and is removed once the build has finished.
    def reference(dest_path)
      @mutex.synchronize { @referenced[relative(dest_path)] = true }
    end

    def referenced?(dest_path)
      @mutex.synchronize { @referenced.key?(relative(dest_path)) }
    end

    def referenced_paths
      @mutex.synchronize { @referenced.keys.dup }
    end

    def save!
      @mutex.synchronize do
        FileUtils.mkdir_p(File.dirname(MANIFEST_PATH))
        File.write(MANIFEST_PATH, JSON.pretty_generate(manifest))

        # Published alongside the images so that the next build - which will most
        # likely start with an empty cache - can reuse them.
        RemoteDerivatives.write_index(manifest['derivatives'], manifest['drive'])
      end
    end

    # Drop everything under imgs/ that this build did not use, both from the
    # cache and from the manifest. Without this, derivatives of photos that were
    # deleted in Drive would live on in the build cache and keep being published.
    #
    # Returns the list of removed paths.
    def prune!
      referenced, referenced_drive = @mutex.synchronize { [@referenced.dup, @referenced_drive.dup] }
      removed = []

      Dir.glob('imgs/**/*').each do |path|
        next unless File.file?(path)
        next if path == MANIFEST_PATH
        next if SCRATCH_FILES.include?(path)
        next if referenced.key?(path)

        File.delete(path)
        removed << path
      end

      @mutex.synchronize do
        manifest['derivatives'].delete_if { |dest, _| !referenced.key?(dest) }
        manifest['drive'].delete_if { |key, _| !referenced_drive.key?(key) }
      end

      removed
    end

    private

    # Caller must hold @mutex.
    def manifest
      @manifest ||= load_manifest
    end

    def load_manifest
      empty = { 'version' => VERSION, 'derivatives' => {}, 'drive' => {} }
      return empty unless File.exist?(MANIFEST_PATH)

      parsed = JSON.parse(File.read(MANIFEST_PATH))
      return empty unless parsed['version'] == VERSION

      empty.merge(parsed)
    rescue JSON::ParserError => e
      puts "   Ignoring unreadable derivative cache at #{MANIFEST_PATH}: #{e.message}".yellow
      empty
    end

  end
end
