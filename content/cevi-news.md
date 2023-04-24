---
title: Die neusten Updates aus dem Cei Züri 11
permalink: /cevi-news
regenerate: true
sub-menu: Cevi Züri 11
sub-menu-name: Cevi News
sub-menu-priority: 4
description: Hier findest du alle News-Beiträge in chronologischer Reihenfolge.
keywords:
  - Cevi Züri 11
  - News
  - Cevi-News
  - Neuigkeiten
  - News-Beiträge
---

# Cevi News

Bei uns im Cevi ist immer etwas los! Hier findest du alle News-Beiträge in chronologischer Reihenfolge.

<div class="news-feed">

    {%- assign pages = site.html_pages | sort: 'date' | reverse -%}
    {%- for p in pages -%}
        {%- if p.news-entry -%}
            <div class="news-entry">
                <span class="news-entry-date">{{ p.date | date: "%m.%d.%Y, %H:%M Uhr" }}</span>
                <h3 class="news-entry-title">{{ p.news-entry-title}}</h3>
                <p class="news-entry-content">{{p.news-entry-caption}} <a href="{{ p.url }}">
                {%- if p.fotos -%} Fotos ansehen... {%- else -%}     Mehr lesen... {%- endif -%}
                </a></p>
            </div>
        {%- endif -%}
    
    {% endfor %}

</div>
