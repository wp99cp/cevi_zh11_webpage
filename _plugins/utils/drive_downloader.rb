require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'
require 'benchmark'
require 'parallel'

module DriveDownloader

  credentials = '_secrets/credentials.json'
  scope = 'https://www.googleapis.com/auth/drive.readonly'

  authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(credentials), scope: scope
  )

  Google::Apis::RequestOptions.default.retries = 5

  @@drive_service = Google::Apis::DriveV3::DriveService.new
  @@drive_service.authorization = authorizer
  @@drive_service.client_options.send_timeout_sec = 20
  @@drive_service.client_options.open_timeout_sec = 20
  @@drive_service.client_options.read_timeout_sec = 20

  @@semaphore = Mutex.new

  def self.list_files(config, folder_id)
    @@semaphore.synchronize do
      ignore_gdrive_cache = config['ignore_gdrive_cache']
      puts 'ignore_gdrive_cache: ' + ignore_gdrive_cache.to_s

      # Check if cache_file exists, if so load from cache
      cache_file = 'google_drive_cache/' + folder_id + '_files.json'

      if File.exist?(cache_file) and ignore_gdrive_cache == false
        puts "Folder content is cached at: #{cache_file}"
        return JSON.parse(File.read(cache_file))
      end

      # Define details of the query
      query = "'#{folder_id}' in parents"
      fields = 'nextPageToken, files(id, name, mimeType, size, parents, trashed, modifiedTime)'

      response = nil
      time = Benchmark.measure {
        response = @@drive_service.list_files(q: query, supports_all_drives: true, corpora: 'user', order_by: 'createdTime desc',
                                              include_items_from_all_drives: true, fields: fields, page_size: 1000)

      }

      # Log the results
      puts 'Time needed to find ' + response.files.length.to_s + ' files: ' + time.real.to_s + 's' unless response.files.empty?
      puts 'No files found' if response.files.empty?

      # filter response.files to only include non-trashed files
      response.files = response.files.select { |file| !file.trashed }

      # Save response.files as JSON into a cache file
      File.open(cache_file, 'w') do |f|
        f.write(JSON.pretty_generate(response.files))
      end

      return JSON.parse(JSON.pretty_generate(response.files))
    end
  end

  def self.get_file(config, file_id)
    @@semaphore.synchronize do
      ignore_gdrive_cache = config['ignore_gdrive_cache']
      puts 'ignore_gdrive_cache: ' + ignore_gdrive_cache.to_s

      # Check if cache_file exists, if so load from cache
      cache_file = 'google_drive_cache/' + file_id + '_file.json'

      if File.exist?(cache_file) and ignore_gdrive_cache == false
        puts "Folder content is cached at: #{cache_file}"
        return JSON.parse(File.read(cache_file))
      end

      fields = 'id, name, mimeType, size, parents, modifiedTime'

      file = @@drive_service.get_file(file_id, supports_all_drives: true, fields: fields)

      # Save response.files as JSON into a cache file
      File.open(cache_file, 'w') do |f|
        f.write(JSON.pretty_generate(file))
      end

      return JSON.parse(JSON.pretty_generate(file))
    end
  end

  def self.download_file(file, directory)
    @@semaphore.synchronize do

      file_name = self.parse_file_name(file['name'])
      file_path = File.join(directory, file_name)

      # remove leading '_' from file_path
      new_file_path = file_path.gsub!(/\/_+/, '/')
      file_path = new_file_path if new_file_path

      if file['mimeType'] == 'image/jpeg'
        file_path += '.jpg'
      elsif file['mimeType'] == 'image/png'
        file_path += '.png'
      elsif file['mimeType'] == 'image/heif'
        file_path += '.heic'
      elsif file['mimeType'] == 'application/pdf'
        file_path += '.pdf'
      elsif file['mimeType'] == 'audio/mpeg'
        file_path += '.mp3'
      end

      if File.file?(file_path.to_s)
        puts " - #{file_path}: File is cached".green
        return file_path
      end

      FileUtils.mkdir_p directory unless File.directory?(directory)

      puts " - #{file_path}: Downloading file".yellow
      @@drive_service.get_file(file['id'], download_dest: file_path, supports_all_drives: true)

      return file_path

    end
  end

  private

  def self.parse_file_name(file_name)

    file_name = file_name.gsub(/\s/, '_')
    file_name.gsub(/\.[^.]*\Z/, '')

  end

end