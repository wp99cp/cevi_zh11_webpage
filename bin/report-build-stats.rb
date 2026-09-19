#!/usr/bin/env ruby
#
# Prints what the build spent its time on, and clears the running totals.
#
# Run at the end of docker-entrypoint.sh, once both Jekyll passes have added
# their numbers. CI lifts the block between the markers into the job summary.

require 'fileutils'

require_relative '../_plugins/utils/build_stats'

build_seconds = Float(ARGV[0]) if ARGV[0] && !ARGV[0].empty?

puts BuildStats.report(BuildStats.read_totals, build_seconds: build_seconds)

FileUtils.rm_f(BuildStats::STATS_PATH)
