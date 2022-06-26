---
title: Fotogallery
main-menu: Fotos
main-menu-priority: 7
permalink: /fotos
regenerate: true
---

# Hier findest du die Fotos vergangener Anlässe.

<div class="news-feed">

    {%- assign pages = site.html_pages | sort: 'date' | reverse | where: 'news-entry' , true -%}
    {%- for p in pages -%}
    
    {%- if p.fotos -%}
    
        <div class="news-entry">
        <span class="news-entry-date">{{ p.date | date: "%m.%d.%Y, %H:%M Uhr" }}</span>
        <h3 class="news-entry-title">{{ p.news-entry-title}}</h3>
        <p class="news-entry-content">{{p.news-entry-caption}} <a href="{{ p.url }}"> Fotos ansehen... </a></p>
        </div>
    
    {%- endif -%}
    {% endfor %}

</div>
