#!/bin/bash
until mysql -h "$RDS_ENDPOINT" -P 3306 -u root -pT2kVB3zgeN3YbrKS --ssl=0 -e "SELECT 1" > /dev/null 2>&1; do
  echo "Waiting for database to be ready..."
  sleep 2
done

mysql -h "$RDS_ENDPOINT" -P 3306 -u root -pT2kVB3zgeN3YbrKS --ssl=0 -e "source /var/www/html/dump.sql"
sed -i "s,RDS_ENDPOINT_VALUE,$RDS_ENDPOINT,g" /var/www/html/config.inc
exec apache2-foreground
