# infrastructure

ARCHITECTURE DIAGRAM :
![ArchitectureDiagram](https://user-images.githubusercontent.com/69026663/108641722-d2652280-746e-11eb-9af1-5e51f3896457.png)




AWS Certificate command : aws acm import-certificate --certificate fileb://prod_tiwariank_me.crt --certificate-chain fileb://prod_tiwariank_me.ca-bundle --private-key fileb://example_com.key


ssh -i prodkeys.pem ubuntu@34.204.69.106
sudo apt install mysql-client-core-5.7
sudo mysql -h csye6225-f20.ckmmnc7r7je6.us-east-1.rds.amazonaws.com -u csye6225fall2020 -p
SELECT id, user, host, connection_type FROM performance_schema.threads pst INNER JOIN information_schema.processlist isp ON pst.processlist_id = isp.id;




WEBAPP,AMI and INFRASTRUCTURE setup for application

1. Create a new ami by triggering github actions by making commit to your repositoryy
2. In infrastructure switch to main branch and create infrastructure by tyoing following command "terraform apply"
3. After infrastructure is setup trigger github actions for code deploy to run and setup webapp on all the EC2 instances present
4. Trigger github actions in serverless repository to setup/update lambda function and setup SNS and SES.
5. Destroy the infrastructure by command "terraform destroy"



ADD SECRETS To GITHUB BEFORE ALL THE SETUPS TO EVERY REPOSITORY:
AWS_ACCESS_KEY
AWS_SECRET_ACCESS_KEY
AWS_S3_BUCKET
AWS_REGION




