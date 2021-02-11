#! /bin/bash
sudo touch /home/ubuntu/.env
sudo echo 'HOST='${db_host}'' >> /home/ubuntu/.env
sudo echo 'PORT='${app_port}'' >> /home/ubuntu/.env
sudo echo 'DB_USER='${db_username}'' >> /home/ubuntu/.env
sudo echo 'DB_PASSWORD='${db_password}'' >> /home/ubuntu/.env
sudo echo 'DATABASE='${db_name}'' >> /home/ubuntu/.env
sudo echo 'AWS_REGION='${region}'' >> /home/ubuntu/.env
sudo echo 'AWS_BUCKET_NAME='${bucket_name}'' >> /home/ubuntu/.env
sudo echo 'DOMAIN_NAME='${aws_domainName}'' >> /home/ubuntu/.env
sudo echo 'AWS_ENVIORMENT='${aws_environment}'' >> /home/ubuntu/.env
sudo echo 'AWS_TOPIC_ARN='${aws_topic_arn}'' >> /home/ubuntu/.env