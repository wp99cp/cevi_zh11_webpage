def swisstopo(map_center_lat, map_center_lon, scale, pkts)

  pkts = pkts.split
  pkts = pkts.map { |str| str.split('/').reverse().map { |c| c.to_f } }

  "<figure>
<div id=\"viewDiv\"></div>
<link rel=\"stylesheet\" href=\"https://js.arcgis.com/4.22/esri/themes/light/main.css\">
<script src=\"https://js.arcgis.com/4.22/\"></script>
<script>
    const points = #{pkts.inspect};
    const map_center = [#{map_center_lon}, #{map_center_lat}];
    const scale = #{scale};
</script>
<script type=\"module\" src=\"script/swisstopo/basic.js\"></script>
</figure>"

end

Jekyll::Hooks.register :pages, :pre_render do |post, payload|

  doc_ext = post.extname.tr('.', '')

  # only process if we deal with a markdown file
  if payload['site']['markdown_ext'].include? doc_ext

    post.content = post.content.gsub(%r{\[\[ swisstopo centered :: (.+)/(.+) :: (.+) :: (.+) \]\]}) do
      swisstopo(Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3), Regexp.last_match(4))
    end

  end
end