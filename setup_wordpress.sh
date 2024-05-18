#!/bin/bash

echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo chown $USER:$USER /var/run/docker.sock

echo "Setting up Docker Swarm..."
docker swarm init

echo "Generating Docker secrets..."
openssl rand -base64 20 | docker secret create mysql_root_password -
openssl rand -base64 20 | docker secret create mysql_password -

echo "Creating MySQL service..."
docker network create -d overlay mysql_private
docker service create \
  --name mysql \
  --replicas 1 \
  --network mysql_private \
  --mount type=volume,source=mydata,destination=/var/lib/mysql \
  --secret source=mysql_root_password,target=mysql_root_password \
  --secret source=mysql_password,target=mysql_password \
  -e MYSQL_ROOT_PASSWORD_FILE="/run/secrets/mysql_root_password" \
  -e MYSQL_PASSWORD_FILE="/run/secrets/mysql_password" \
  -e MYSQL_USER="wordpress" \
  -e MYSQL_DATABASE="wordpress" \
  mysql:latest

echo "Creating WordPress service..."
docker service create \
  --name wordpress \
  --replicas 1 \
  --network mysql_private \
  --publish published=30000,target=80 \
  --mount type=volume,source=wpdata,destination=/var/www/html \
  --secret source=mysql_password,target=wp_db_password \
  -e WORDPRESS_DB_USER="wordpress" \
  -e WORDPRESS_DB_PASSWORD_FILE="/run/secrets/wp_db_password" \
  -e WORDPRESS_DB_HOST="mysql:3306" \
  -e WORDPRESS_DB_NAME="wordpress" \
  wordpress:latest

echo "Verifying services..."
docker service ls
docker service ps wordpress