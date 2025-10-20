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

def generate_liquid_tag(file, full_file_name, nofollow)
  # Build the list of arguments for the Liquid tag
  tag_args = [
    full_file_name,
    "#{file['name'].gsub(/\.[^.]*\Z/, '')}",
    "#{date_to_string(file['modifiedTime'])}"
  ]

  # Add 'nofollow' to the arguments if the flag is true
  tag_args << 'nofollow' if nofollow

  # Construct the final tag string by joining arguments with '::'
  "{% document #{tag_args.join(' :: ')} %}"
end

def google_drive(config, element_type, uuid, nofollow: false)
  case element_type
  when 'folder'

    files = DriveDownloader.list_files(config, uuid)

    result = '<div class=" documents ">'
    files.each do |file|
      puts "#{file['name']} (#{file['id']}, #{file['mimeType']})"

      # filter for supported file types
      next unless %w[application/pdf audio/mpeg].include? file['mimeType']

      full_file_name = DriveDownloader.download_file(file, 'docs')
      # Pass the nofollow flag to the tag generator
      result += "\n#{generate_liquid_tag(file, full_file_name, nofollow)}"
    end

    result += '</div>'
    return result

  when 'document'

    file = DriveDownloader.get_file(config, uuid)
    full_file_name = DriveDownloader.download_file(file, 'docs')
    # Pass the nofollow flag to the tag generator
    return generate_liquid_tag(file, full_file_name, nofollow)

  else
    return ''
  end
end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|
  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext
    post.content = post.content.gsub(/\[\[ google_drive (.+?) :: (.+) \]\]/) do
      args_string = Regexp.last_match(1).strip
      uuid = Regexp.last_match(2).strip

      args = args_string.split(/\s+/) # e.g., ["folder"] or ["folder", "nofollow"]
      element_type = args[0]
      nofollow_flag = args.include?('nofollow')

      google_drive(post.site.config, element_type, uuid, nofollow: nofollow_flag)
    end
  end
end