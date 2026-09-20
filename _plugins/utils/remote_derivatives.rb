require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'
require 'yaml'

require_relative 'build_stats'

# Second-tier cache: the images already published on the live site.
#
# GitHub deletes an Actions cache entry that has not been read for seven days,
# and this site often goes months between commits, so in practice almost every
# build starts with an empty imgs/ directory and regenerates everything - over an
# hour of downloading photos from Drive and re-encoding them.
#
# The deployed site is a copy of exactly those images that never expires. When a
# derivative is missing locally we therefore try to fetch it from there before
# falling back to rebuilding it, which turns megabytes of Drive download plus
# seconds of ImageMagick into one small HTTP GET.
#
# Reusing a published file is only safe if it was produced from the same input,
# so each build also publishes an index mapping every image to a digest of its
# cache key, and a file is only reused when that digest still matches. The
# digest, rather than the key itself, is what gets published: the key of a
# gallery photo contains its Google Drive id, which does not belong on a public
# webpage.
module RemoteDerivatives

  INDEX_PATH = 'imgs/derivatives-index.json'.freeze
  VERSION = 1

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20

  @mutex = Mutex.new
  @index = nil
  @disabled = false

  class << self

    def digest(key)
      Digest::SHA256.hexdigest(key)
    end

    # The index this build publishes, so that the next one can reuse its output.
    def build_index(derivatives, drive)
      entries = derivatives.transform_values { |key| digest(key) }

      photos = drive.each_with_object({}) do |(key, entry), result|
        result[digest(key)] = entry
      end

      { 'version' => VERSION, 'entries' => entries, 'photos' => photos }
    end

    def write_index(derivatives, drive)
      FileUtils.mkdir_p(File.dirname(INDEX_PATH))
      File.write(INDEX_PATH, JSON.pretty_generate(build_index(derivatives, drive)))
    end

    # What the live site knows about a photo (whether it is tagged for the
    # webpage, and the dimensions of its large version), so that an unchanged
    # photo does not have to be downloaded from Drive just to be measured.
    def photo(key)
      index&.dig('photos', digest(key))
    end

    # Fetches dest_path from the live site, but only if the published index says
    # it was built from the same input. Returns true when the file is in place.
    def fetch(path, key, dest_path)
      return false unless index
      return false unless index.dig('entries', path) == digest(key)

      body = BuildStats.time(:remote_fetch) { get("#{base_url}/#{path}") }
      return false if body.nil?

      FileUtils.mkdir_p(File.dirname(dest_path))
      File.binwrite(dest_path, body)
      File.chmod(0644, dest_path)

      puts " - Restored #{path} from #{base_url}".green
      true
    rescue StandardError => e
      puts " - Could not restore #{path} from the live site: #{e.message}".yellow
      false
    end

    private

    def index
      @mutex.synchronize do
        return nil if @disabled
        return @index unless @index.nil?

        @index = load_index
        @disabled = @index.nil?
        @index
      end
    end

    def load_index
      return nil if ENV['NO_REMOTE_DERIVATIVES']
      return nil if base_url.nil? || base_url.empty?

      body = get("#{base_url}/#{INDEX_PATH}")
      if body.nil?
        puts "No published image index at #{base_url}/#{INDEX_PATH}; building every image from scratch.".yellow
        return nil
      end

      parsed = JSON.parse(body)
      return nil unless parsed['version'] == VERSION

      puts "Reusing images already published on #{base_url} where they are still current.".blue
      parsed
    rescue StandardError => e
      puts "Could not read the published image index: #{e.message}".yellow
      nil
    end

    def base_url
      @base_url ||= (ENV['DERIVATIVES_BASE_URL'] || site_url).to_s.chomp('/')
    end

    def site_url
      YAML.load_file('_config.yml')['url']
    rescue StandardError
      nil
    end

    def get(url)
      # Escaped first: file names such as stufe_fröschli.jpg are not ASCII, and
      # URI.parse rejects those outright rather than encoding them.
      uri = URI.parse(URI::DEFAULT_PARSER.escape(url))
      return nil unless uri.is_a?(URI::HTTP)

      response = Net::HTTP.start(uri.host, uri.port,
                                 use_ssl: uri.scheme == 'https',
                                 open_timeout: OPEN_TIMEOUT,
                                 read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri)
      end

      response.is_a?(Net::HTTPSuccess) ? response.body : nil
    rescue StandardError
      nil
    end

  end
end
