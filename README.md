# infrastructure


AWS Certificate command : aws acm import-certificate --certificate fileb://prod_tiwariank_me.crt --certificate-chain fileb://prod_tiwariank_me.ca-bundle --private-key fileb://example_com.key


ssh -i prodkeys.pem ubuntu@34.204.69.106
sudo apt install mysql-client-core-5.7
sudo mysql -h csye6225-f20.ckmmnc7r7je6.us-east-1.rds.amazonaws.com -u csye6225fall2020 -p
SELECT id, user, host, connection_type FROM performance_schema.threads pst INNER JOIN information_schema.processlist isp ON pst.processlist_id = isp.id;