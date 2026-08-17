FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sqlite3 \
        libsqlite3-dev \
	vim \
    && docker-php-ext-install pdo pdo_sqlite \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite headers

# Note that the directories below are inside of the container, not on your local machine.

# Delete the default Apache httpd configuration with the one for the container.
# Don't worry, there is a copy of this in /etc/apache2/sites-available
RUN rm /etc/apache2/sites-enabled/000-default.conf
COPY conf/001-api-demo.conf /etc/apache2/sites-enabled/001-api-demo.conf

# Directory for sqlite database outside of webroot:
RUN mkdir /var/lib/sqlite-data
RUN chown -R www-data:www-data /var/lib/sqlite-data

# Directory for app-related secrets outside of webroot:
RUN mkdir /var/lib/secrets
COPY secrets/sh-dbinfo.php /var/lib/secrets
# We need to create the Pepper File in Secrets.  It will contain a random string that is appended to the API_KEY before it is hashed/base64 encoded.
RUN LOCAL_PEPPER="$(openssl rand -hex 64)" && \
	cat <<EOF >> /var/lib/secrets/pepper.php
<?php
define ('PEPPER', '${LOCAL_PEPPER}');
?>
EOF

# Make sure that the web process can read the secrets directory.
RUN chown -R www-data:www-data /var/lib/secrets

# Apply PHP Production configuration
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Create the API endpoint directory and grant ownership to web process user if not already done.
RUN mkdir /var/www/html/api
COPY html/api/* /var/www/html/api

# This sets the default directory into which everything is processed.
# This is also the directory you land in when you jump into a running container.
WORKDIR /var/www/html

COPY html/db-conn-test.php .
COPY html/index.php .
COPY html/make-access-token.php .
COPY html/make-access-token-top.txt .
COPY html/make-access-token-bottom.txt .
COPY html/phpinfo.php .
COPY html/sh-common-noauth.php .
# The below command will recurisvely change ownership for everything in webroot, including the api directory.
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
