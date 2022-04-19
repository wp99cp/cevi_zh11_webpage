require 'fileutils'
require 'securerandom'

$active_forms = "backend/active_forms"

# Removes the old form config files
FileUtils.rm_rf Dir.glob("#{$active_forms}/*.yml")

def contact_form(config)

  uuid = 'id-' + SecureRandom.alphanumeric(8)
  create_backend_code(uuid)

  "<form class=\"input-container\" id=\"#{uuid}\"
      action=\"javascript:send_message('#{uuid}', '#{config['backend']}')\">
  <script src=\"script/contact_form/contact_form.js\"/></script>
    <div class=\"styled-input\">
			<input type=\"text\" required />
			<label>Vorname</label>
		</div>
		<div class=\"styled-input\">
			<input type=\"text\" required />
			<label>Nachname</label>
		</div>
	    <div class=\"styled-input wide\">
			<input type=\"mail\" required />
			<label>Mail</label>
		</div>
		<div class=\"styled-input wide\">
			<textarea required></textarea>
			<label>Nachricht</label>
		</div>
		<button type='submit'>Nachricht senden</button>
</form>"

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

    post.content = post.content.gsub(/\[\[ contact-form \]\]/) do
      contact_form(post.site.config)
    end

  end
end