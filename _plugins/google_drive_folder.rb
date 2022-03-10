require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'

def parse_file_name(file_name)

  file_name = file_name.gsub(/\s/, '_')
  file_name.gsub(/\.[^.]*\Z/, '')

end

def date_to_string(timestamp)

  return '' if timestamp == nil

  DateTime.parse(timestamp.to_s).strftime('%d. %b %Y').to_s

end

def download_document(drive_service, file)

  directory = 'docs'
  file_name = parse_file_name(file.name)
  file_path = File.join(directory, file_name)
  file_path += '.pdf'

  if File.file?(file_path.to_s)
    puts 'File is cached'
    return file_path
  end

  FileUtils.mkdir_p directory unless File.directory?(directory)

  puts "Download file: #{file_path}"
  drive_service.get_file(file.id, download_dest: file_path, supports_all_drives: true)
  file_path

end

def generate_liquid_tag(file, full_file_name)
  "{% document #{full_file_name} :: #{file.name.gsub(/\.[^.]*\Z/, '')} :: #{date_to_string(file.modified_time)}  %}"
end

def google_drive(element_type, uuid)

  credentials = '_secrets/credentials.json'
  scope = 'https://www.googleapis.com/auth/drive.readonly'

  authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(credentials), scope: scope
  )

  drive_service = Google::Apis::DriveV3::DriveService.new
  drive_service.authorization = authorizer

  case element_type
  when 'folder'

    puts uuid

    folder_id = uuid
    query = "parents = '#{folder_id}'"
    fields = 'nextPageToken, files(id, name, mimeType, size, parents, modifiedTime)'

    response = drive_service.list_files(q: query, supports_all_drives: true, corpora: 'allDrives',
                                        include_items_from_all_drives: true, fields: fields)

    puts 'No files found' if response.files.empty?

    result = '<div class=" documents ">'
    response.files.each do |file|
      puts "#{file.name} (#{file.id}, #{file.mime_type})"
      next unless file.mime_type == 'application/pdf'

      full_file_name = download_document(drive_service, file)
      result += "\n#{generate_liquid_tag(file, full_file_name)}"

    end

    result += '</div>'
    result

  when 'document'

    file = drive_service.get_file(uuid, supports_all_drives: true)

    full_file_name = download_document(drive_service, file)
    generate_liquid_tag(file, full_file_name)

  else
    ''

  end

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ google_drive (.+) :: (.+) \]\]/) { google_drive(Regexp.last_match(1), Regexp.last_match(2)) }

  end
end