def cite(author, cite)

  "<cite class=\"cite-block\">\"#{cite}\"
<span class=\"author-block\">#{author}</span>
</cite>"

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ cite :: (.+) :: (.+) \]\]/) do
      cite(Regexp.last_match(1), Regexp.last_match(2))
    end

  end
end