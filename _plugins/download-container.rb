module Jekyll
  class DownloadDocument < Liquid::Tag

    def initialize(tag_name, input, tokens)
      super
      @input = input
    end

    def split_params(params)
      params.split('::').map(&:strip)
    end

    def render(context)

      args = split_params(@input)
      doc_path = args[0]
      doc_description = args[1]
      doc_change_date = args[2]

      icon_type = "pdf-icon"

      if doc_path.include?(".mp3")
        icon_type = "mp3-icon"
      end

      "<div class=\" download-container \">
        <a href=\"/#{doc_path}\" #{("download=\"/#{doc_path}\"" unless icon_type == "pdf-icon")}>
          <icon class=\" download-icon #{icon_type} \"></icon>
          <span class=\" download-title \">#{doc_description}</span>
          <span class=\" download-change-date \">Hochgeladen am #{doc_change_date}</span>
        </a>
      </div>"

    end
  end
end

Liquid::Template.register_tag('document', Jekyll::DownloadDocument)