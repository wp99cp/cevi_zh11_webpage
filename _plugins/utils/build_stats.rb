require 'json'

# Counts and times the expensive parts of a build.
#
# Almost all of a build is spent downloading photos from Google Drive and
# re-encoding them; rendering the site itself is well under a minute. Whether a
# run takes four minutes or eighty therefore comes down to how many images the
# caches managed to avoid rebuilding - which is invisible from the outside, and
# was invisible for long enough that the image cache silently did nothing at all
# for years.
#
# Every run now reports that breakdown, so a regression shows up as a number
# rather than as a build that is mysteriously slow again.
#
# The site is built twice (some pages need a second pass), and each pass is its
# own process, so the numbers are accumulated in a file and rendered once both
# passes are done - see bin/report-build-stats.rb.
module BuildStats

  STATS_PATH = '.build-stats.json'.freeze

  # Printed around the report so CI can lift it into the job summary.
  BEGIN_MARKER = '::build-stats-begin::'.freeze
  END_MARKER = '::build-stats-end::'.freeze

  # Rendered in this order; anything not listed here is left out of the report.
  # The last element says which columns are worth showing for that row.
  LABELS = [
    [:gallery_reused, 'Gallery photos reused, not rebuilt', :count],
    [:gallery_built, 'Gallery photos downloaded from Drive and converted', :count],
    [:local_reused, 'Other images reused, not rebuilt', :count],
    [:local_built, 'Other images converted', :count],
    [:remote_fetch, 'Images taken from the live site instead of rebuilt', :both],
    [:drive_listing, 'Google Drive folder listings', :both],
    [:drive_download, 'Time spent downloading photos from Drive', :time],
    [:convert, 'Time spent in ImageMagick', :time]
  ].freeze

  @mutex = Mutex.new
  @counts = Hash.new(0)
  @seconds = Hash.new(0.0)

  class << self

    def count(key, by = 1)
      @mutex.synchronize { @counts[key] += by }
    end

    # Counts the call and adds however long it took.
    def time(key)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        yield
      ensure
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @mutex.synchronize do
          @counts[key] += 1
          @seconds[key] += elapsed
        end
      end
    end

    # Adds this pass's numbers to whatever earlier passes recorded.
    def flush!
      @mutex.synchronize do
        totals = read_totals

        @counts.each { |key, value| totals['counts'][key.to_s] = totals['counts'].fetch(key.to_s, 0) + value }
        @seconds.each { |key, value| totals['seconds'][key.to_s] = totals['seconds'].fetch(key.to_s, 0.0) + value }

        File.write(STATS_PATH, JSON.pretty_generate(totals))

        @counts.clear
        @seconds.clear
      end
    end

    def read_totals
      return { 'counts' => {}, 'seconds' => {} } unless File.exist?(STATS_PATH)

      parsed = JSON.parse(File.read(STATS_PATH))
      { 'counts' => parsed['counts'] || {}, 'seconds' => parsed['seconds'] || {} }
    rescue JSON::ParserError
      { 'counts' => {}, 'seconds' => {} }
    end

    # A markdown table, because CI drops it straight into the job summary.
    def report(totals = read_totals, build_seconds: nil)
      counts = totals['counts']
      seconds = totals['seconds']

      rows = LABELS.filter_map do |key, label, show|
        name = key.to_s
        next unless counts.key?(name)

        count = show == :time ? '' : counts[name]
        duration = seconds[name]
        duration = show == :count || duration.nil? ? '' : format('%.1fs', duration)

        "| #{label} | #{count} | #{duration} |"
      end

      lines = [BEGIN_MARKER, '### Where the build spent its time', '']

      if rows.empty?
        lines << 'No images were processed.'
      else
        lines << '| | count | time |'
        lines << '| --- | ---: | ---: |'
        lines.concat(rows)
      end

      lines << '' << "Total build time: #{format('%.0fs', build_seconds)}" if build_seconds
      lines << END_MARKER

      lines.join("\n")
    end

  end
end
