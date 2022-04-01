---
permalink: /cevi-news
---

# Cevi News

Bei uns im Cevi ist immer etwas los! Hier findest du alle News-Beiträge in chronologischer Reihenfolge.

<div class="news-feed">

{%- assign pages = site.html_pages | sort: 'date' | reverse | where: 'news-entry' , true -%}
{%- for p in pages -%}
<div class="news-entry">
<span class="news-entry-date">{{ p.date | date: "%m.%d.%Y, %H:%M Uhr" }}</span>
<h3 class="news-entry-title">{{ p.news-entry-title}}</h3>
<p class="news-entry-content">{{p.news-entry-caption}} <a href="{{ p.url }}"> Mehr lesen... </a></p>
</div>

{% endfor %}


</div>