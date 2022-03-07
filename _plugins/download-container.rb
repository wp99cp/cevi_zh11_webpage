module Jekyll
  class RenderTimeTag < Liquid::Tag

    def initialize(tag_name, input, tokens)
      super
      @input = input
    end

    def split_params(params)
      params.split("::").map(&:strip)
    end

    def render(context)

      args = split_params(@input)
      doc_path = args[0]
      doc_description = args[1]
      doc_change_date = args[2]

      output = "<div class=\" download-container \">
        <a href=\"#{doc_path}\">
          <icon class=\" download-icon pdf-icon \"></icon>
          <span class=\" download-title \">#{doc_description}</span>
          <span class=\" download-change-date \">Hochgeladen am #{doc_change_date}</span>
        </a>
      </div>"

      output

    end
  end
end

Liquid::Template.register_tag('document', Jekyll::RenderTimeTag)