require 'google/apis/drive_v3'
require 'googleauth'
require 'fileutils'
require 'date'
require_relative 'utils/drive_downloader'

def parse_file_name(file_name)

  file_name = file_name.gsub(/\s/, '_')
  file_name.gsub(/\.[^.]*\Z/, '')

end

def date_to_string(timestamp)

  return '' if timestamp == nil

  DateTime.parse(timestamp.to_s).strftime('%d.%m.%Y').to_s

end

def generate_liquid_tag(file, full_file_name)
  "{% document #{full_file_name} :: #{file['name'].gsub(/\.[^.]*\Z/, '')} :: #{date_to_string(file['modifiedTime'])}  %}"
end

def google_drive(config, element_type, uuid)

  case element_type
  when 'folder'

    files = DriveDownloader.list_files(config, uuid)

    result = '<div class=" documents ">'
    files.each do |file|
      puts "#{file['name']} (#{file['id']}, #{file['mimeType']})"

      # filter for supported file types
      next unless %w[application/pdf audio/mpeg].include? file['mimeType']

      full_file_name = DriveDownloader.download_file(file, 'docs')
      result += "\n#{generate_liquid_tag(file, full_file_name)}"

    end

    result += '</div>'
    return result

  when 'document'

    file = DriveDownloader.get_file(config, uuid)
    full_file_name = DriveDownloader.download_file(file, 'docs')
    return generate_liquid_tag(file, full_file_name)

  else
    return ''
  end

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ google_drive (.+) :: (.+) \]\]/) { google_drive(post.site.config, Regexp.last_match(1), Regexp.last_match(2)) }

  end
end