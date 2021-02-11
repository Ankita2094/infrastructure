provider "aws"{
    profile = var.profile
    region = var.region
}

data "aws_acm_certificate" "aws_ssl_certificate" {
  domain = "${var.env}.${var.domainName}"
  most_recent = true
}

#Getting AWS Availability Zone
data "aws_availability_zones" "availablilityZones" {}


# Getting the Account ID of AWS Account
data "aws_caller_identity" "env" {}

locals {
  aws_account_id = data.aws_caller_identity.env.account_id
}

# Creating a VPC 
resource "aws_vpc" "vpc"{

    cidr_block = var.cidrBlockVPC
    

    enable_dns_support = var.dnsSup
    enable_dns_hostnames = var.hosts
    enable_classiclink_dns_support = true
    assign_generated_ipv6_cidr_block = false

    tags = {
        Name = "${var.vpcName}_${timestamp()}"
    }
}

# Creating subnets
resource "aws_subnet" "subnet"{

    count = length(var.cidrBlockSubnet)

    cidr_block = var.cidrBlockSubnet[count.index]

    vpc_id = aws_vpc.vpc.id
    availability_zone = data.aws_availability_zones.availablilityZones.names[count.index]
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.vpcName}_Subnet${count.index}"
    }
}

# Creating an Internet Gateway
resource "aws_internet_gateway" "igw" {

    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "${var.vpcName}_InternetGateway"
    }
}

# Creating the Route Table
resource "aws_default_route_table" "route_table" {

    default_route_table_id = aws_vpc.vpc.default_route_table_id

    tags = {
        Name = "${var.vpcName}_RouteTable"
    }
}

# Create the Internet Access
resource "aws_route" "vpc_internet_access" {

  route_table_id = aws_default_route_table.route_table.id
  destination_cidr_block = var.cidrBlockDestination
  gateway_id = aws_internet_gateway.igw.id

}

# Connecting Route Table with the Subnets
resource "aws_route_table_association" "subnetAssociation" {

    count = length(var.cidrBlockSubnet)
    subnet_id = element(aws_subnet.subnet.*.id, count.index)
    route_table_id = aws_default_route_table.route_table.id

}



#Load Balancer Security Group
resource "aws_security_group" "loadbalancer" {
  name          = "loadbalancer_security_group"
  vpc_id        = aws_vpc.vpc.id
  ingress{
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks  = var.cidrBlockIngress
  }
  # Egress is used here to communicate anywhere with any given protocol
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = var.cidrBlockEgress
  }
  tags          = {
    Name        = "LoadBalancer Security Group"
    Description = "Load Balancer Security Group"
  }
}





# Creating Application Security Group
resource "aws_security_group" "app_security_group" {
  name         = "app_security_group"
  vpc_id       = aws_vpc.vpc.id
  
  # allow ingress of port 22
  # ingress {
   # cidr_blocks = var.cidrBlockIngress  
   # from_port   = 22
   # to_port     = 22
   # protocol    = "tcp"
   # security_groups = ["${aws_security_group.loadbalancer.id}"]
  # } 

   # allow ingress of port 80
 # ingress {
  #  cidr_blocks = var.cidrBlockIngress  
  #  from_port   = 80
  #  to_port     = 80
  #  protocol    = "tcp"
   # security_groups = ["${aws_security_group.loadbalancer.id}"]
  #} 

  # allow ingress of port 80
  # ingress {
  #  cidr_blocks = var.cidrBlockIngress  
  #  from_port   = 443
  #  to_port     = 443
  #  protocol    = "tcp"
  #  security_groups = ["${aws_security_group.loadbalancer.id}"]
  # } 

   # allow ingress of port 8080
 ingress {
   # cidr_blocks = var.cidrBlockIngress  
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = ["${aws_security_group.loadbalancer.id}"]
  } 
  
  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.cidrBlockEgress
    security_groups = ["${aws_security_group.loadbalancer.id}"]
  }

    tags = {
        Name = "App_Security_Group"
        Description = "App Security Group"
    }
}

# Creating Database Security Group
resource "aws_security_group" "db_security_group" {

  name         = "db_security_group"
  vpc_id       = aws_vpc.vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.app_security_group.id ]
  } 

  tags = {
        Name = "DB_Security_Group"
        Description = "DB Security Group"
  }
}

# Creating S3 Bucket
resource "aws_s3_bucket" "S3Bucket" {

  bucket = var.S3BucketName
  acl = "private"
  force_destroy = "true"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle_rule {
    enabled = true

    transition {
      days = 30
      storage_class = "STANDARD_IA"
    }
  }

  tags = {
        Name = var.S3BucketName
        Description = "S3 Bucket"
  }

   depends_on = [aws_subnet.subnet]

}
resource "aws_s3_bucket_public_access_block" "s3Private" {
  bucket = aws_s3_bucket.S3Bucket.id
  ignore_public_acls = true
  block_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
}

# Creating RDS DB Subnet Group
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-subnet"
  subnet_ids = aws_subnet.subnet.*.id

  tags = {
    Name = "RDS Subnet"
  }
}

# Creating RDS Datbase Instance
resource "aws_db_instance" "rdsDB" {

    allocated_storage = 20
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t3.micro"
    publicly_accessible = false
    multi_az = false
    identifier = var.DBInstanceIdentifier
    name = var.rdsDatabaseName
    username = var.masterUsername
    password = var.masterPassword
    skip_final_snapshot = true
    storage_encrypted = true
    vpc_security_group_ids = [ aws_security_group.db_security_group.id ]
    db_subnet_group_name = aws_db_subnet_group.rds_subnet.id
    parameter_group_name = aws_db_parameter_group.db_parameter_group.name

}


resource "aws_db_parameter_group" "db_parameter_group" {
  name = "rds-pg"
  family = "mysql5.7"

  parameter {
    name  = "performance_schema"
    value = "1"
    apply_method = "pending-reboot"
  }
}

#Creating DynamoDB Table
resource "aws_dynamodb_table" "DynamoDbTable" {
    name  = var.dynamoDatabaseName
    billing_mode   = "PROVISIONED"
    read_capacity  = 20
    write_capacity = 20
    hash_key = "email_hash"

    attribute {
      name = "email_hash"
      type = "S"
    }

    ttl {
    attribute_name = "ttl"
    enabled = true
    }

    tags = {
      Name = var.dynamoDatabaseName
    }
}

# IAM Roles

# IAM Role for EC2 Instance
resource "aws_iam_role" "EC2_Role" {
  name = "EC2-CSYE6225"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "EC2-CSYE6225"
  }
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codeDeploy_role" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM Role for CodeDeploy EC2
resource "aws_iam_role" "codeDeploy_EC2_role" {
  name = "CodeDeployEC2ServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# CodeDeploy Application 
resource "aws_codedeploy_app" "codeDeploy_application" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

# CodeDeploy Deployment Group 
resource "aws_codedeploy_deployment_group" "codeDeploy_deploymentGroup" {
  app_name              = aws_codedeploy_app.codeDeploy_application.name
  deployment_group_name = "csye6225-webapp-deployment"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn      = aws_iam_role.codeDeploy_role.arn
  autoscaling_groups    = ["${aws_autoscaling_group.autoscaling.name}"]

  load_balancer_info {
    target_group_info {
      name = "${aws_lb_target_group.alb-target-group.name}"
    }
  }

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "EC2Instance-CSYE6225"
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  alarm_configuration {
    alarms  = ["Deployment-Alarm"]
    enabled = true
  }

  depends_on = [aws_codedeploy_app.codeDeploy_application]
}


# IAM Policies

# IAM Policy for ghactions User
resource "aws_iam_policy" "GH-E2-Instance" {
  name = "GH-E2-Instance"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CopyImage",
                "ec2:CreateImage",
                "ec2:CreateKeypair",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteKeyPair",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSnapshot",
                "ec2:DeleteVolume",
                "ec2:DeregisterImage",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeRegions",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:GetPasswordData",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifySnapshotAttribute",
                "ec2:RegisterImage",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_policy" "GH-Upload-To-S3" {
  name = "GH-Upload-To-S3"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
         "s3:Get*",
         "s3:List*"
        ],
      "Resource":[ 
        "arn:aws:s3:::codedeploy.${var.env}.${var.domainName}/*",
        "arn:aws:s3:::codedeploy.${var.env}.${var.domainName}",
        "arn:aws:s3:::lambda.${var.env}.${var.domainName}/*"
      ]
    }
  ]
}
EOF
}
resource "aws_iam_policy" "GH-Code-Deploy" {
  name = "GH-Code-Deploy"
  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": "arn:aws:codedeploy:${var.region}:${local.aws_account_id}:application:${aws_codedeploy_app.codeDeploy_application.name}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": "arn:aws:codedeploy:${var.region}:${local.aws_account_id}:deploymentgroup:${aws_codedeploy_app.codeDeploy_application.name}/${aws_codedeploy_deployment_group.codeDeploy_deploymentGroup.deployment_group_name}"
      
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${local.aws_account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.region}:${local.aws_account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.region}:${local.aws_account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}

# IAM Policy for CodeDeploy Role
# This policy allows EC2 Instance to read & upload data from S3 bucket.
resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
  name = "CodeDeploy-EC2-S3"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::codedeploy.${var.env}.${var.domainName}/*",
        "arn:aws:s3:::${var.S3BucketName}/*"
      ]
    }
  ]
}
EOF
}

# IAM Policy for S3 Bucket 
resource "aws_iam_policy" "S3_Policy" {
  name = "WebAppS3_Policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::${var.S3BucketName}/*"
        }
    ]
}
EOF
}

# Lambda Policy for GH
resource "aws_iam_policy" "GH-Lambda" {
  name = "GH-Lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*"
        ],

      "Resource": "arn:aws:lambda:${var.region}:${local.aws_account_id}:function:${aws_lambda_function.sns_lambda_email.function_name}"
    }
  ]
}
EOF
}

# IAM User and Policies Attachment

# ghaction User and EC2 Instance Policy Attachment

resource "aws_iam_user_policy_attachment" "ghactions_EC2_policy_attach" {
  user = "ghaction"
  policy_arn = aws_iam_policy.GH-E2-Instance.arn
}

# ghactions User and S3 Policy Attachment

resource "aws_iam_user_policy_attachment" "ghactions_S3_policy_attach" {
  user = "ghaction"
  policy_arn = aws_iam_policy.GH-Upload-To-S3.arn
}

# ghaction User and CodeDeploy Policy Attachment

resource "aws_iam_user_policy_attachment" "ghactions_codeDeploy_policy_attach" {
  user = "ghaction"
  policy_arn = aws_iam_policy.GH-Code-Deploy.arn
}

# ghaction User and Lambda Policy Attachmen
resource "aws_iam_user_policy_attachment" "ghactions_lambda_policy_attach" {
  policy_arn = aws_iam_policy.GH-Lambda.arn
  user = "ghaction"
}


# IAM Roles and Policies Attachments

# Policy to the EC2 role for CloudWatch Agent
resource "aws_iam_role_policy_attachment" "cloud_watch_EC2" {
  role = aws_iam_role.codeDeploy_EC2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# CodeDeploy Role and CodeDeploy Policy Attachment
resource "aws_iam_role_policy_attachment" "CodeDeployRole_CodeDeployPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codeDeploy_role.name
}

# CodeDeploy Role and EC2 Instances Policy Attachment
resource "aws_iam_role_policy_attachment" "CodeDeployRole_EC2Policy" {
  policy_arn = aws_iam_policy.CodeDeploy-EC2-S3.arn
  role       = aws_iam_role.codeDeploy_EC2_role.name
}

# EC2 Role and S3 Policy Attachment
resource "aws_iam_role_policy_attachment" "EC2Role_S3Policy" {
  role       = aws_iam_role.codeDeploy_EC2_role.name
  policy_arn = aws_iam_policy.S3_Policy.arn

}

// Fetch latest published AMI
data "aws_ami" "application_ami" {
  owners = [var.accountId]
  most_recent = true

  filter {
    name   = "name"
    values = ["csye6225_*"]
  }
}

# Profile for the EC2 Instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role =  aws_iam_role.codeDeploy_EC2_role.name
}

# EC2 Instance
# resource "aws_instance" "ec2_instance" {

 #  ami = data.aws_ami.application_ami.id
 #  instance_type = "t2.micro"
  # vpc_security_group_ids = [ aws_security_group.app_security_group.id ]
  # disable_api_termination = false
  # key_name = var.ssh_key
  # subnet_id = aws_subnet.subnet[0].id
  # associate_public_ip_address = true
  # iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  # user_data = templatefile("${path.module}/aws_userdata.sh",
                  # {
                   # db_host = aws_db_instance.rdsDB.address,
                  #  app_port = var.AppPort,
                  #  bucket_name = aws_s3_bucket.S3Bucket.id,
                  #  db_name = aws_db_instance.rdsDB.name,
                  #  db_username = aws_db_instance.rdsDB.username,
                  #  db_password = aws_db_instance.rdsDB.password,
                  #  region = var.region
                 # })

  # root_block_device {
    # volume_type = "gp2"
    # volume_size = "20"
    # delete_on_termination = true
  # }

  # tags = {
    # Name = "EC2Instance-CSYE6225"
  # }

 # depends_on = [aws_s3_bucket.S3Bucket,aws_db_instance.rdsDB]
   
# }


 # Route 53 Zone Data
data "aws_route53_zone" "selected" {
  name         = "${var.env}.${var.domainName}"
  private_zone = false
}

 # Add/Update DNS record to public IP of EC2 Instance
 resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  # name    = "api.${var.env}.${var.domainName}"
  name = data.aws_route53_zone.selected.name
  type    = "A"
  # ttl     = "60"
  alias {
    name    = "${aws_lb.appLoadbalancer.dns_name}"
    zone_id = "${aws_lb.appLoadbalancer.zone_id}"
    evaluate_target_health = true
  }
  # records = [aws_instance.ec2_instance.public_ip]
  # depends_on = [aws_instance.ec2_instance]
}


# Auto Scaling Launch Configuration
resource "aws_launch_configuration" "asg_launch_config" {
  name          = "asg_launch_config"
  image_id      = "${data.aws_ami.application_ami.id}"
  instance_type = "t2.micro"
  security_groups = [ "${aws_security_group.app_security_group.id}" ]
  key_name      = "${var.ssh_key}"
   user_data = templatefile("${path.module}/aws_userdata.sh",
                   {
                    db_host = aws_db_instance.rdsDB.address,
                    app_port = var.AppPort,
                    bucket_name = aws_s3_bucket.S3Bucket.id,
                    db_name = aws_db_instance.rdsDB.name,
                    db_username = aws_db_instance.rdsDB.username,
                    db_password = aws_db_instance.rdsDB.password,
                    region = var.region
                    aws_environment = var.env,
                    aws_domainName = var.domainName,
                    aws_topic_arn = aws_sns_topic.sns_webapp.arn
                  })

  associate_public_ip_address = true
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.name}"

  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
    delete_on_termination = true
  }

  depends_on = [aws_s3_bucket.S3Bucket,aws_db_instance.rdsDB]
}




resource "aws_lb_target_group" "alb-target-group" {  
  name     = "alb-target-group"  
  port     = "8080"  
  protocol = "HTTP"  
  vpc_id   = aws_vpc.vpc.id  
  tags     = {    
    name = "alb-target-group"    
  }   
  health_check {    
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    path                = "/healthstatus"
    port                = "8080"
    matcher = "200"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "autoscaling" {
  name                 = "asg_launch_config"
  launch_configuration = "${aws_launch_configuration.asg_launch_config.name}"
  min_size             = 3
  max_size             = 5
  default_cooldown     = 60
  desired_capacity     = 3
  # load_balancers     = ["${aws_lb.appLoadbalancer.name}"]
  vpc_zone_identifier = aws_subnet.subnet.*.id
  
  target_group_arns    = ["${aws_lb_target_group.alb-target-group.arn}"]

  tag {
    key                 = "Name"
    value               = "EC2Instance-CSYE6225"
    propagate_at_launch = true
  }
}

# Auto Scaling Policies

## Auto scaling policies
resource "aws_autoscaling_policy" "WebServerScaleUpPolicy" {
  name                   = "WebServerScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling.name}"
}

resource "aws_autoscaling_policy" "WebServerScaleDownPolicy" {
  name                   = "WebServerScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling.name}"
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling.name}"
  }
  alarm_description = "Scale-up if CPU > 90% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.WebServerScaleUpPolicy.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "3"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling.name}"
  }
  alarm_description = "Scale-down if CPU < 70% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.WebServerScaleDownPolicy.arn}"]
}


# Application Load Balancer 
resource "aws_lb" "appLoadbalancer" {
  name               = "appLoadbalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.loadbalancer.id}"]
  subnets            = aws_subnet.subnet.*.id
  ip_address_type    = "ipv4"
  tags = {
    Environment = "${var.env}"
    Name = "appLoadbalancer"
  }
}



resource "aws_lb_listener" "webapp_listener" {
  load_balancer_arn = "${aws_lb.appLoadbalancer.arn}"
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.aws_ssl_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.alb-target-group.arn}"
  }
}



#SNS topic and policies
resource "aws_sns_topic" "sns_webapp" {
  name = "email_webapp_sns"
}

resource "aws_sns_topic_policy" "sns_webapp_policy" {
  arn = "${aws_sns_topic.sns_webapp.arn}"
  policy = "${data.aws_iam_policy_document.sns-topic-policy.json}"
}

data "aws_iam_policy_document" "sns-topic-policy" {
 # policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        "${local.aws_account_id}",
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "${aws_sns_topic.sns_webapp.arn}",
    ]

   # sid = "__default_statement_ID"
  }
}

# IAM- SNS policy
resource "aws_iam_policy" "sns_iam_policy" {
  name = "ec2_iam_sns_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "SNS:Publish"
      ],
      "Resource": "${aws_sns_topic.sns_webapp.arn}"
    }
  ]
}
EOF
}

# SNS topic policy-EC2 role attachment
resource "aws_iam_role_policy_attachment" "ec2_sns" {
  policy_arn = aws_iam_policy.sns_iam_policy.arn
  role = aws_iam_role.codeDeploy_EC2_role.name
}

#Lambda Function
resource "aws_lambda_function" "sns_lambda_email" {
  filename      = "function.zip"
  function_name = "lambda_function_email"
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "index.handler"
  runtime       = "nodejs10.x"
  source_code_hash = "${filebase64sha256("function.zip")}"
 # environment {
  #  variables = {
  #    timeToLive = "${var.timeToLive}"
  #  }
 # }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name  = "lambda/${aws_lambda_function.sns_lambda_email.function_name}"
}

#SNS topic subscription to Lambda
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = "${aws_sns_topic.sns_webapp.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.sns_lambda_email.arn}"
}


#SNS Lambda permission
resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_lambda_email.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_webapp.arn
}

# Lambda Policy
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for Cloud watch and Code Deploy"
  policy      = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Effect": "Allow",
           "Action": "logs:CreateLogGroup",
           "Resource": "arn:aws:logs:${var.region}:${local.aws_account_id}:*"
       },
        {
           "Effect": "Allow",
           "Action": [
               "logs:CreateLogStream",
               "logs:PutLogEvents"
           ],
           "Resource": [
              "arn:aws:logs:${var.region}:${local.aws_account_id}:log-group:/aws/lambda/${aws_lambda_function.sns_lambda_email.function_name}:*"
          ]
       },
       {
         "Sid": "LambdaDynamoDBAccess",
         "Effect": "Allow",
         "Action": [
             "dynamodb:GetItem",
             "dynamodb:PutItem",
             "dynamodb:UpdateItem",
             "dynamodb:Scan",
             "dynamodb:DeleteItem"
         ],
         "Resource": "arn:aws:dynamodb:${var.region}:${local.aws_account_id}:table/${var.dynamoDatabaseName}"
       },
       {
         "Sid": "LambdaSESAccess",
         "Effect": "Allow",
         "Action": [
             "ses:VerifyEmailAddress",
             "ses:SendEmail",
             "ses:SendRawEmail"
         ],
         "Resource": "*",
          "Condition":{
            "StringEquals":{
              "ses:FromAddress":"${var.fromAddress}@${var.env}.${var.domainName}"
            }
          }
       }
   ]
}
 EOF
}


#IAM Role for lambda with sns
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


#Attach the policy for Lambda iam role
resource "aws_iam_role_policy_attachment" "lambda_role_policy_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}