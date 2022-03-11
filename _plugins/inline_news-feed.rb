def news_feed

  "<div>
<section class=\"news-feed-inline-container\"> {%- include news-feed.html n_limit=\"2\" -%} </section>
</div>"

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(/\[\[ news-feed \]\]/) do
      news_feed
    end

  end
end