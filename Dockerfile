FROM jekyll/builder:4.4.1

# Install native dependencies: ImageMagick (rmagick / mini_magick), Ghostscript
# and ExifTool are used by the gallery and responsive-image plugins.
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        imagemagick \
        libmagickwand-dev \
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
