Jekyll::Hooks.register :pages, :pre_render do |post, payload|
  docExt = post.extname.tr('.', '')
  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? docExt
    newContent = post.content.gsub(/\!\[(.+)\]\((.+)\)/, '{% image \2 :: \1 :: \1  %}')
    post.content = newContent
  end
end