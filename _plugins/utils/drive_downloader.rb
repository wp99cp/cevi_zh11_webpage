require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'
require 'benchmark'
require 'parallel'

module DriveDownloader

  CREDENTIALS = '_secrets/credentials.json'.freeze
  SCOPE = 'https://www.googleapis.com/auth/drive.readonly'.freeze

  @@authorizer = nil

  if File.exist?(CREDENTIALS)
    begin
      @@authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(CREDENTIALS), scope: SCOPE
      )

      Google::Apis::RequestOptions.default.retries = 5
    rescue => e
      puts "Error loading Google Drive credentials: #{e.message}"
    end
  else
    puts "Google Drive credentials not found at #{CREDENTIALS}. Google Drive sync is disabled."
  end

  # A DriveService is not safe to share between threads, so each thread gets its
  # own. They are cheap; the expensive part (the signed credentials) is shared.
  def self.drive_service
    return nil if @@authorizer.nil?

    Thread.current[:drive_service] ||= begin
      service = Google::Apis::DriveV3::DriveService.new
      service.authorization = @@authorizer
      service.client_options.send_timeout_sec = 20
      service.client_options.open_timeout_sec = 20
      service.client_options.read_timeout_sec = 20
      service
    end
  end

  def self.available?
    !@@authorizer.nil?
  end

  # Building the site without Drive silently produces empty galleries and a
  # documents section with no documents, which looks like a successful build and
  # deploys a gutted page. That is only ever acceptable when working locally.
  def self.require_available!
    return if available?
    return unless ENV['CI']

    raise "Google Drive credentials are missing or unusable (#{CREDENTIALS}). " \
          'Refusing to build a site with empty galleries.'
  end

  # Guards the on-disk json caches; the network calls themselves run unguarded.
  @@cache_mutex = Mutex.new

  def self.list_files(config, folder_id)
    require_available!

    ignore_gdrive_cache = config['ignore_gdrive_cache']
    cache_file = 'google_drive_cache/' + folder_id + '_files.json'

    # The listing is deliberately *not* reused in production. It is the only
    # thing that decides which photos appear on the page, so it has to be
    # re-fetched on every build - otherwise a photo deleted in Drive would keep
    # being published. Caching the derived images (see DerivativeCache) is what
    # makes the build fast; caching the listing would make it wrong.
    if File.exist?(cache_file) && ignore_gdrive_cache == false
      puts "Folder content is cached at: #{cache_file}"
      return @@cache_mutex.synchronize { JSON.parse(File.read(cache_file)) }
    end

    if drive_service.nil?
      puts 'Google Drive service not initialized (missing credentials).'
      return []
    end

    # Define details of the query
    query = "'#{folder_id}' in parents"
    fields = 'nextPageToken, files(id, name, mimeType, size, parents, trashed, modifiedTime)'

    response = nil
    time = Benchmark.measure {
      response = drive_service.list_files(q: query, supports_all_drives: true, corpora: 'user', order_by: 'createdTime desc',
                                          include_items_from_all_drives: true, fields: fields, page_size: 1000)

    }

    # Log the results
    puts ('Time needed to find ' + response.files.length.to_s + ' files: ' + time.real.to_s + 's').blue unless response.files.empty?
    puts 'No files found'.red if response.files.empty?

    # filter response.files to only include non-trashed files
    response.files = response.files.select { |file| !file.trashed }

    files = JSON.pretty_generate(response.files)

    @@cache_mutex.synchronize do
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, files)
    end

    JSON.parse(files)
  end

  def self.get_file(config, file_id)
    require_available!

    ignore_gdrive_cache = config['ignore_gdrive_cache']
    cache_file = 'google_drive_cache/' + file_id + '_file.json'

    if File.exist?(cache_file) && ignore_gdrive_cache == false
      puts "Folder content is cached at: #{cache_file}"
      return @@cache_mutex.synchronize { JSON.parse(File.read(cache_file)) }
    end

    if drive_service.nil?
      puts 'Google Drive service not initialized (missing credentials).'
      return nil
    end

    fields = 'id, name, mimeType, size, parents, modifiedTime'
    file = JSON.pretty_generate(drive_service.get_file(file_id, supports_all_drives: true, fields: fields))

    @@cache_mutex.synchronize do
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, file)
    end

    JSON.parse(file)
  end

  EXTENSIONS = {
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/heif' => '.heic',
    'application/pdf' => '.pdf',
    'audio/mpeg' => '.mp3'
  }.freeze

  # Where a Drive file would be downloaded to. Deriving this without touching the
  # network lets the gallery work out the names of the images it is about to
  # build, and skip the download entirely when they are already cached.
  def self.local_path_for(file, directory, prefix = '')
    file_name = prefix
    file_name += '_' unless prefix
    file_name += parse_file_name(file['name'])

    # remove leading '_' from the file name
    file_path = File.join(directory, file_name).gsub(/\/_+/, '/')

    file_path + EXTENSIONS.fetch(file['mimeType'], '')
  end

  def self.download_file(file, directory, prefix = '')
    return nil if file.nil?

    file_path = local_path_for(file, directory, prefix)

    if File.file?(file_path.to_s)
      puts " - #{file_path}: File is cached".green
      return file_path
    end

    if drive_service.nil?
      puts "Google Drive service not initialized (missing credentials). Cannot download #{file['name']}."
      return nil
    end

    @@cache_mutex.synchronize { FileUtils.mkdir_p directory unless File.directory?(directory) }

    puts " - #{file_path}: Downloading file".yellow
    drive_service.get_file(file['id'], download_dest: file_path, supports_all_drives: true)

    file_path
  end

  def self.parse_file_name(file_name)
    file_name = file_name.gsub(/\s/, '_')
    file_name.gsub(/\.[^.]*\Z/, '')
  end

end
