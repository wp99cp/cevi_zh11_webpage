# Cevi Züri 11 - Webseite

Dieses Repo enthält die offizielle Webseite des Cevi Züri 11. Unser Ziel ist es alle Kindern und Jugendlichen eine
sinnvolle und abwechslungsreiche Freizeitbeschäftigung anzubieten. Jeden Samstag organisieren wir für Naturbegeisterte
ein spannendes Programm im und um den Wald an.

## Wie bearbeite ich den Inhalt?

Um den Inhalt der Seite zu bearbeiten, kannst du die meisten Files ein diesem Ordner ignorieren. Für dich ist lediglich
der Ordner `content`, `docs` und `assets` wichtig. Alle anderen Ordner und Dateien werden für das Layout und den Style
usw. gebraucht.

Der Ordner  `content` enthält für jede Unterseite auf der Webpage ein eigens Dokument. Geschrieben in Markdown, dies
erlaubt es dir den Text wie in Word rudimentär zu stylen, trotzdem sieht die Webseite anschliessend einheitlich
aus: [eine kurze Einführung](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet). Um Markdown-Text zu
bearbeiten, empfehle ich dir den folgenden Editor: [Mark Text](https://marktext.app/).

Wichtig ist dabei, dass ein Dokument immer mit den folgenden Zeilen beginnt:

```
---
# Definiert den Style der Seite: Zur Zeit gibt es nur einen Seiten-Style, page.
layout: page

# Name dieser Seite im Hauptmenü / Footer-Menü. Möchtest du diese Seite nicht im Hauptmenü angezeigt haben,
# so kannst du diese Zeile weglassen
main-menu: Über uns 
footer-menu: Über uns 

# Name des Links (der URL) der zu dieser Seite führt. Beginnt immer mit `/` als alias für `https://zh11.ch/`.
permalink: /uerber-uns
---
```

Im Ordner `assets` werden sämtliche Bilder gespeichert, Bilder müssen immer im `assets` Ordner gespeichert werden und
___NICHT___ im `imgs` Ordner. Denn hier werden die optimierten und resized Bilder automatisch abgelegt. Im Ordner `docs`
alle Dokument, die heruntergeladen werden können.

# For developers

This page uses a custom Jekyll template.

## Local Development of the page

1) Clone this repo into a local folder
2) Install imagemagick:

```bash 
$ sudo apt-get install imagemagick
```

5) Install jekyll following the instructions on the [official webpage](https://jekyllrb.com/docs/installation/).
6) Install all dependencies as listed in the `Gemfile` using
```bash 
$ bundle install
```

8) Serve the webpage locally by running the following command:

```bash 
$ bundle exec jekyll serve --livereload
```

4) Start editing and enjoy!

## Image Optimizing Pipeline

We are using an automatic pipeline for image optimizing. This allows us for the content creator to use images out of a
camara, those images are huge in filesize, e.g. around 2MB. The pipeline now automatically creates five images in
different size and optimizes them for file site. From our original image we get for example a 450x300px image with a
file size of 40kB.

The image optimizing pipeline is implemented in `_plugins/pre-processor.rb` and `_plugins/image-optimizer.rb`.

The first script converts the markdown image tag into a custom format, which is the used by the second script to
generate HTML code.

The pre-processor takes in markdown code and converts an image:

```markdown
![Image description used as subtitle and alt text.](assets/path/to/image.jpg)
```

to the custom liquid tag:

```markdown
{{% image assets/path/to/image.jpg :: Image description used as subtitle and alt text. :: Image description used as
subtitle and alt text. %}
```

Which then gets processed by the image optimizer into, the image-optimizer automatically creates all needed image files
and stores them in the `imgs` folder.

```html
<figure>
    <img src="/imgs/path/to/image.jpg_1800x1200.jpg" alt="Image description used as subtitle and alt text."
         srcset=" /imgs/path/to/image_1800x1200.jpg 1800w, /imgs/path/to/image_1200x800.jpg 1200w,
                               /imgs/path/to/image_1125x750.jpg 1125w,  /imgs/path/to/image_600x400.jpg 600w,
                               /imgs/path/to/image_450x300.jpg 450w ">
    <span> Image description used as subtitle and alt text. </span>
</figure>
```

