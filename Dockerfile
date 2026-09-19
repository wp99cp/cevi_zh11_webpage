FROM jekyll/builder:4.4.1

# Install native dependencies: ImageMagick (rmagick / mini_magick), Ghostscript
# and ExifTool are used by the gallery and responsive-image plugins.
# libheif-plugin-x265 adds the HEIC *encoder*; without it ImageMagick can only
# read HEIC, and the in-place mogrify calls on iPhone photos from Google Drive
# fail with "no encode delegate for this image format `HEIC'".
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        imagemagick \
        libmagickwand-dev \
        libheif-plugin-x265 \
        ghostscript \
        libimage-exiftool-perl && \
    rm -rf /var/lib/apt/lists/*

# Font copy
COPY ./fonts/ /usr/share/fonts/

# Download and install minify CLI
RUN wget -O /tmp/minify.tar.gz https://github.com/tdewolff/minify/releases/download/v2.24.13/minify_linux_amd64.tar.gz && \
    tar -xzf /tmp/minify.tar.gz -C /usr/bin minify && \
    rm /tmp/minify.tar.gz


COPY Gemfile* ./
RUN bundler install

# Default is production mode.
# If you want to use development mode, set this variable to false.
ENV MODE=production

# docker-entrypoint: source and exec
COPY ./docker-entrypoint.sh ./
RUN chmod +x ./docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
