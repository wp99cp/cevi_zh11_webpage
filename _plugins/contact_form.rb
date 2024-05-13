require 'fileutils'
require 'securerandom'
require 'yaml'

$active_forms = "backend/active_forms"

# Removes the old form config files
FileUtils.rm_rf Dir.glob("#{$active_forms}/*.yml")

def contact_form(config, config_file)

  uuid = 'id-' + SecureRandom.alphanumeric(8)
  create_backend_code(uuid)

  form_config = YAML.load_file(config_file)

  html_code = "<form class=\"input-container\" id=\"#{uuid}\"
      action=\"javascript:send_message('#{uuid}', '#{config['backend']}', '#{form_config['receiver']}')\">
  <script src=\"/script/contact_form/contact_form.js\"/></script>"

  form_config['cells'].each do |cell|

    cell_uuid = 'id-' + SecureRandom.alphanumeric(8)
    visibility_state = "grid"

    if cell.key?('condition')
        # conditioned elements are hidden by default, they get only shown if the condition is met

        postfix = SecureRandom.alphanumeric(4)
        visibility_state = "none"
        html_code += "<script>
            const checkbox_#{postfix} = document.getElementById('#{cell["condition"]}');
            checkbox_#{postfix}.addEventListener('change', function() {
                if (checkbox_#{postfix}.checked) {
                    document.getElementById('#{cell_uuid}').style.display = 'grid';
                } else {
                    document.getElementById('#{cell_uuid}').style.display = 'none';
                }
            });
        </script>"
    end

    if cell['element'] == 'input'

      html_code += "<div style=\"display: #{visibility_state};\" id=\"#{cell_uuid}\" class=\"styled-input " +
        (cell['style_wide'] ? "wide" : "") + "\">"
      html_code += "<input content='' onchange=\"this.setAttribute('content', this.value);\" type=\""
      html_code += (cell['type'] ? cell['type'] : "text")
      html_code += "\" "
      html_code += (cell['required'] ? " required />" : " />")

    elsif cell['element'] == 'textarea'

      html_code += "<div style=\"display: #{visibility_state};\"  id=\"#{cell_uuid}\" class=\"styled-textarea " +
        (cell['style_wide'] ? "wide" : "") + "\">"
      html_code += "<textarea content='' onchange=\"this.setAttribute('content', this.value);\" "
      html_code += (cell['required'] ? " required >" : ">") + "</textarea>"

    elsif cell['element'] == 'checkbox'

      html_code += "<div style=\"display: #{visibility_state};\" id=\"#{cell_uuid}\" class=\"styled-checkbox " +
        (cell['style_wide'] ? "wide" : "") + "\">"
      html_code += "<input id=\"#{cell["id"]}\" content=\"false\" onchange=\"this.setAttribute('content', this.checked);\" type=\"checkbox\" "
      html_code += (cell['required'] ? " required />" : "/>")
    end

    html_code += "<label>" + cell['label'] + "</label></div>"

  end

  html_code += "<button type='submit'>Nachricht senden</button></form>"
  html_code

end

def create_backend_code(uuid)

  FileUtils.mkdir_p('backend')

  out_file = File.new("#{$active_forms}/#{uuid}.yml", 'w')
  out_file.puts('write your stuff here')
  out_file.close

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ contact-form :: (.+) \]\]/) do
      contact_form(post.site.config, Regexp.last_match(1))
    end

  end
end