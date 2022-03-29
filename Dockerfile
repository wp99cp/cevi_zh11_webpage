FROM jekyll/builder:latest

# Install Jekyll
RUN apk --no-cache add php8-pecl-imagick ghostscript

# Font copy
COPY ./fonts/ /usr/share/fonts/
