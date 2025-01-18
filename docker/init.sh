#!/bin/sh

# تغییر مالکیت و مجوزها
chown -R www-data:www-data /usr/share/nginx/html
chmod -R 755 /usr/share/nginx/html
find /usr/share/nginx/html -type f -exec chmod 644 {} \;
