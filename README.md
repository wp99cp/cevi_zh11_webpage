# Cevi Züri 11 - Webseite

Dieses Repo enthält die offizielle Webseite des Cevi Züri 11. Unser Ziel ist es alle Kindern und Jugendlichen eine
sinnvolle und abwechslungsreiche Freizeitbeschäftigung anzubieten. Jeden Samstag organisieren wir für Naturbegeisterte
ein spannendes Programm im und um den Wald an.

## Wie bearbeite ich den Inhalt?

Um den Inhalt der Seite zu bearbeiten, kannst du die meisten Files ein diesem Ordner ignorieren. Für dich ist lediglich
der Ordner `content` und `assets` wichtig. Alle anderen Ordner und Dateien werden für das Layout und den Style usw.
gebraucht.

### Content: Der eigentliche Text der Webseite

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

### Assets: Speicherort für Bilder usw.

Im Ordner `assets` werden sämtliche Bilder gespeichert, Bilder müssen immer im `assets` Ordner gespeichert werden und
___NICHT___ im `imgs` Ordner. Denn hier werden die optimierten und resized Bilder automatisch abgelegt. Im Ordner `docs`
alle Dokument, die heruntergeladen werden können.

Bilder können anschliessend einfach eingefügt werden, hierzu wird der standard Markdown-Tag verwendet:

```markdown
![Titel des Bildes](/assets/path/to/image.jpg)
```

Alternativ kannst du auch direkt den entsprechenden Liquid Tag verwenden,
siehe https://github.com/wp99cp/responsive_images_for_jekyll.

### Dokumente und Ordner einfügen

Dokeumente sollen direkt von Google Drive eingefügt werden. Speichere hierzu dein Dokument auf dem Cevi Züri 11 Drive im
Ordner [Dokumente für Webseite](https://drive.google.com/drive/folders/161HIx9ViSero3GOUQQKNzQKNPswFPTPJ?usp=sharing).
Hierzu kannst du an einer beliebigen Stelle in deinem Markdown File die folgende Zeile einfügen:

```markdown
[[ google_drive <<element_type>> :: <<element_ref_id>> ]]
```

Dabei musst du `<<element_type>>` mit `folder` oder `document` ersetzten. Je nach dem, ob du einen ganzen Ordner oder
nur ein einzelnes Dokument zum Download freigeben willst. Die `<<element_ref_id>>` musst du mit der entsprechenden ID
des Ordners bzw. Dokumentes ersetzten. Siehe folgendes Beispiel:

1) Du möchtest folgendes Dokument
   freigeben: [Teilnahmebedingungen](https://drive.google.com/file/d/115qZ_Yr60DDYEBR-Ek4K962E4QdGdCl7/view?usp=sharing)
2) Das Dokument ist bereits im richtigen Ordner abgespeichert, du brauchst also nur noch die `<<element_ref_id>>`, diese
   ist Teil des Freigabelinks: `https://drive.google.com/file/d/115qZ_Yr60DDYEBR-Ek4K962E4QdGdCl7/view?usp=sharing`
   ergibt `115qZ_Yr60DDYEBR-Ek4K962E4QdGdCl7` als `<<element_ref_id>>`.
3) Zusammen ergibt es folgende Zeile, wichtig ist dabei dass es vor und nach `::` jeweils einen Leerschlag hat ebenso
   vor bzw. nach den doppelten, eckigen Klammern.
   ```markdown
   [[ google_drive document :: 115qZ_Yr60DDYEBR-Ek4K962E4QdGdCl7 ]]
   ```

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

7) In order to support including documents from your organization's Google Drive, you need to create a service account
   in the Google Cloud Console and share the folder containing the document with that service account. Then place the
   JSON containing the secrets inside the folder `_secrets/credentials.json`.

8) Serve the webpage locally by running the following command:

```bash 
$ bundle exec jekyll serve --livereload
```

9) Start editing and enjoy!

# Using a docker container to build the page 

```
$ docker build -t jeykell-custom-builder .
$ docker run --rm   --volume="$PWD:/srv/jekyll"   -it jeykell-custom-builder  jekyll build
$ docker run --rm   --volume="$PWD:/srv/jekyll"   --publish [::1]:4000:4000  -it jeykell-custom-builder  jekyll serve
```