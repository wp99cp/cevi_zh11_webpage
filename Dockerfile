FROM jekyll/builder:latest

# Install Jekyll
RUN apk --no-cache add php8-pecl-imagick ghostscript go

# Font copy
COPY ./fonts/ /usr/share/fonts/

ENV GOPATH=$HOME/gocode
ENV PATH=$PATH:$GOPATH/bin
RUN go install github.com/tdewolff/minify/cmd/minify@latest

# docker-entrypoint: source and exec
COPY ./docker-entrypoint.sh ./
RUN chmod +x ./docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]