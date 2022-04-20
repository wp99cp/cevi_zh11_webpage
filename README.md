[![Jekyll Deploy Page](https://github.com/wp99cp/cevi_zh11_webpage/actions/workflows/deploy.yml/badge.svg)](https://github.com/wp99cp/cevi_zh11_webpage/actions/workflows/deploy.yml)
[![pages-build-deployment](https://github.com/wp99cp/cevi_zh11_webpage/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/wp99cp/cevi_zh11_webpage/actions/workflows/pages/pages-build-deployment)

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

### Karte mit eingezeichnetem Punkt

Mit folgender Zeile kannst du an der aktuellen Stelle eine Karte einfügen. Dabei kannst du den Kartenmassstab und den
Mittelpunkt angeben. Für die Karte wird Swisstopo verwendet.

```markdown
[[ swisstopo centered :: 47.41727/8.52754 :: 8_500 :: 47.42010/8.53516 47.41702/8.52278 ]]
```

### Gallery mit Fotos aus einem Google Drive Ordner

Mit folgender Zeile kannst du eine Foto-Gallery erstellt aus einem beliebeigen Google Drive Ordner erstellen.

```markdown
[[ gallery 1BXA-VgYp_E5QqmS7-lUapeVZ3-mFUFaQ ]]
```

# For developers

This page uses a custom Jekyll template.

## Local Development using Docker

The easiest way to build and serve the site locally is using docker-compose. Assuming you have installed docker and
docker-compose, you just need to run the following command without the need of installing any packages or additional
software.

The command will build and server the frontend and start up a local backend server for the webpage.

```bash
$ docker-compose up --build
```

Start editing and enjoy!

### Using Standalone Docker Containers

The application is split in two docker containers, one for the frontend and one for the backend. Here is how to build
and server the frontend.

Build the container and flag it with `jeykell-builder`

```bash
$ docker build -t jeykell-builder .
```

Now you can build the page by running the build `jeykell-builder` container:

```bash
$ docker run --rm --volume="$PWD:/srv/jekyll" -it jeykell-builder
```

This creates a new directory `./_site` with our build site.

If you wish to serve the page locally, you can run the docker container with the `"jekyll serve"` argument. This will
first build and then execute these additional commands inside the brackets. This two step build process is needed in
order to add static files, i.g. the `docs` folder correctly:

```bash
$ docker run --rm --volume="$PWD:/srv/jekyll" --publish [::1]:4000:4000  -it jeykell-builder jekyll serve  --livereload
```

## Local Development without docker

Alternatively, you can install all dependencies directly to your system and build the page without the docker container.
Please follow the instructions provided:

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

   The service account needs access to the Google Drive API.

9) Serve the webpage locally by running the following command:

```bash 
$ bundle exec jekyll serve --livereload --host=0.0.0.0
```

9) Start editing and enjoy!

## Hosting with Firebase

We use firebase for hosting our webpage. Each commit / PR to the master branch triggers an automatic deployment to the
firebase _live_ channel. This workflow is defined in `./github/workflows/deploy.yml`.