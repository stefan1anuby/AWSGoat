FROM php:8.1-apache

RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli
RUN apt-get update && apt-get upgrade -y
# I think we should delete these lines below
RUN apt-get install mariadb-client -y
RUN apt-get install -y python3 sudo vim libcap2-bin fdisk net-tools netcat-openbsd curl unzip zip
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY ./src /var/www/html
COPY ./script /usr/local/bin

RUN chmod +x /usr/local/bin/startup.sh && sed -i 's/\r$//' /usr/local/bin/startup.sh
RUN cd /var/www/html && composer install --no-dev --no-interaction

RUN chown -R www-data /var/www/html/documents
RUN echo "www-data ALL=NOPASSWD:/usr/bin/vim /var/www/html/documents" >> /etc/sudoers

RUN chmod 774 -R /var/www/html/documents

CMD ["/usr/local/bin/startup.sh"]
EXPOSE 80
