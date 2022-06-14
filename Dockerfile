FROM jekyll/builder:latest

# Install Jekyll
RUN apk --no-cache add php8-pecl-imagick ghostscript go exiftool

# Font copy
COPY ./fonts/ /usr/share/fonts/

ENV GOPATH=$HOME/gocode
ENV PATH=$PATH:$GOPATH/bin
RUN go install github.com/tdewolff/minify/cmd/minify@latest

COPY Gemfile* ./
RUN bundler install

# Default is production mode.
# If you want to use development mode, set this variable to false.
ENV MODE=production

# docker-entrypoint: source and exec
COPY ./docker-entrypoint.sh ./
RUN chmod +x ./docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]