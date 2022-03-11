def contact_form

  "<div class=\"input-container\">
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
		<button>Nachricht senden</button>
</div>"

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ contact-form \]\]/) do
      contact_form
    end

  end
end