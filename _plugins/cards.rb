require 'fileutils'
require 'securerandom'
require 'yaml'

$active_forms = "backend/active_forms"

# Removes the old form config files
FileUtils.rm_rf Dir.glob("#{$active_forms}/*.yml")

def create_cards(config_file)

  forms_config = YAML.load_file(config_file)

  html_code = "<div class=\"cards\">"

  forms_config['cards'].each do |card|

    puts config_file.split("/")[-1].split(".")[0]
    page_name = (config_file.split("/")[-1].split(".")[0] + ' ' + card['name']).downcase.gsub!(/\s/, '_')
    link = "/kontakt/" + page_name
    link = card['link'] ? card['link'] : link

    if %w[with_picture without_picture].include? forms_config['type']

      html_code += "<a href=\"#{link}\" class=\"card\">"
      if forms_config['type'] == 'with_picture'
        html_code += "<div class=\"card-image\">"
        html_code += "<img src=\"#{card['image']}\" alt=\"#{card['name']}\">"
        html_code += "</div>"
      end
      html_code += "<div class=\"card-content\">"
      html_code += "<span><b>#{card['name']}<br>#{card['cevi-name']}</b></span>"
      html_code += "<span>#{card['function']}</span>"
      html_code += "</div>"
      html_code += "</a>"

      unless card['link']

        # create a markdown file and save it in the auto_generated_pages folder
        markdown_file = File.new("contact/auto_generated_pages/#{page_name}.md", "w")
        markdown_file.puts("---")
        markdown_file.puts("permalink: #{link}")
        markdown_file.puts("title: #{card['name']} v/o #{card['cevi-name']}")
        markdown_file.puts("---")
        markdown_file.puts("# Nimm mit uns Kontakt auf!")
        markdown_file.puts("## Kontakt zu #{card['name']} v/o #{card['cevi-name']}")
        markdown_file.puts("")
        markdown_file.puts("[[ contact-form :: #{card['contact_form']} ]]")

      end

    end

  end

  html_code += "</div>"
  html_code

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ cards :: (.+) \]\]/) do
      create_cards(Regexp.last_match(1))
    end

  end
end
