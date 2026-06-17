terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = ""
    key            = ""
    region         = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# TODO!!: THIS SHOULD BE PUT IN ANOTHER FILE
variable "ecs_image_uri" {
  type        = string
  description = "Passed from GitHub Actions"
}

# VPC Config for public access
resource "aws_vpc" "lab-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "AWS_GOAT_VPC"
  }
}
resource "aws_subnet" "lab-subnet-public-1" {
  vpc_id                  = aws_vpc.lab-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]
}
resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.lab-vpc.id
  tags = {
    Name = "My VPC - Internet Gateway"
  }
}
resource "aws_route_table" "my_vpc_us_east_1_public_rt" {
  vpc_id = aws_vpc.lab-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_vpc_igw.id
  }

  tags = {
    Name = "Public Subnet Route Table."
  }
}

resource "aws_route_table_association" "my_vpc_us_east_1a_public" {
  subnet_id      = aws_subnet.lab-subnet-public-1.id
  route_table_id = aws_route_table.my_vpc_us_east_1_public_rt.id
}
resource "aws_subnet" "lab-subnet-public-1b" {
  vpc_id                  = aws_vpc.lab-vpc.id
  cidr_block              = "10.0.128.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
}
resource "aws_route_table_association" "my_vpc_us_east_1b_public" {
  subnet_id      = aws_subnet.lab-subnet-public-1b.id
  route_table_id = aws_route_table.my_vpc_us_east_1_public_rt.id
}

resource "aws_security_group" "ecs_sg" {
  name        = "ECS-SG"
  description = "SG for cluster created from terraform"
  vpc_id      = aws_vpc.lab-vpc.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

}

# Create Database Subnet Group
# terraform aws db subnet group
resource "aws_db_subnet_group" "database-subnet-group" {
  name        = "database subnets"
  subnet_ids  = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  description = "Subnets for Database Instance"

  tags = {
    Name = "Database Subnets"
  }
}

# Create Security Group for the Database
# terraform aws create security group

resource "aws_security_group" "database-security-group" {
  name        = "Database Security Group"
  description = "Enable MYSQL Aurora access on Port 3306"
  vpc_id      = aws_vpc.lab-vpc.id

  ingress {
    description     = "MYSQL/Aurora Access"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ecs_sg.id}"]
  }

  tags = {
    Name = "rds-db-sg"
  }

}

# Create Database Instance Restored from DB Snapshots
# terraform aws db instance
resource "aws_db_instance" "database-instance" {
  identifier             = "aws-goat-db"
  allocated_storage      = 10
  instance_class         = "db.t3.micro"
  engine                 = "mysql"
  engine_version         = "8.0"
  username               = "root"
  password               = "T2kVB3zgeN3YbrKS"
  #parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  availability_zone      = "eu-central-1a"
  db_subnet_group_name   = aws_db_subnet_group.database-subnet-group.name
  vpc_security_group_ids = [aws_security_group.database-security-group.id]
  storage_encrypted      = true

  parameter_group_name            = aws_db_parameter_group.rds_logging_params.name
  option_group_name               = aws_db_option_group.rds_audit_options.name
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
}



resource "aws_security_group" "load_balancer_security_group" {
  name        = "Load-Balancer-SG"
  description = "SG for load balancer created from terraform"
  vpc_id      = aws_vpc.lab-vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-goat-m2-sg"
  }
}



resource "aws_iam_role" "ecs-instance-role" {
  name                 = "ecs-instance-role"
  path                 = "/"
  permissions_boundary = aws_iam_policy.instance_boundary_policy.arn
  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment-1" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment-2" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment-3" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = aws_iam_policy.ecs_instance_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs-instance-logs" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "ecs_instance_policy" {
  name = "aws-goat-instance-policy"
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "ssm:*",
          "ssmmessages:*",
          "ec2:RunInstances",
          "ec2:Describe*"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Pol1"
      }
    ],
    "Version" : "2012-10-17"
  })
}

resource "aws_iam_policy" "instance_boundary_policy" {
  name = "aws-goat-instance-boundary-policy"
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "iam:List*",
          "iam:Get*",
          "iam:PassRole",
          "iam:PutRole*",
          "ssm:*",
          "ssmmessages:*",
          "ec2:RunInstances",
          "ec2:Describe*",
          "ecs:*",
          "ecr:*",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Pol1"
      }
    ],
    "Version" : "2012-10-17"
  })
}

resource "aws_iam_instance_profile" "ec2-deployer-profile" {
  name = "ec2Deployer"
  path = "/"
  role = aws_iam_role.ec2-deployer-role.id
}
resource "aws_iam_role" "ec2-deployer-role" {
  name = "ec2Deployer-role"
  path = "/"
  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_deployer_admin_policy" {
  name = "ec2DeployerAdmin-policy"
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "*"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Policy1"
      }
    ],
    "Version" : "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "ec2-deployer-role-attachment" {
  role       = aws_iam_role.ec2-deployer-role.name
  policy_arn = aws_iam_policy.ec2_deployer_admin_policy.arn
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name = "ecs-instance-profile"
  path = "/"
  role = aws_iam_role.ecs-instance-role.id
}
resource "aws_iam_role" "ecs-task-role" {
  name = "ecs-task-role"
  path = "/"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-attachment" {
  role       = aws_iam_role.ecs-task-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs-task-role-attachment-2" {
  role       = aws_iam_role.ecs-task-role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment-ssm" {
  role       = aws_iam_role.ecs-instance-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


data "aws_ami" "ecs_optimized_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.202*-x86_64-ebs"]
  }
}


resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "ecs-launch-template-"
  image_id      = data.aws_ami.ecs_optimized_ami.id
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs-instance-profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_sg.id]
  user_data              = base64encode(data.template_file.user_data.rendered)

  metadata_options {
    http_tokens = "required"
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ECS-lab-asg"
  vpc_zone_identifier = [aws_subnet.lab-subnet-public-1.id]
  desired_capacity    = 1
  min_size            = 0
  max_size            = 1

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }
}


resource "aws_ecs_cluster" "cluster" {
  name = "ecs-lab-cluster"

  tags = {
    name = "ecs-cluster-name"
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/resources/ecs/user_data.tpl")
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/ECS-Lab-Task-definition"
  retention_in_days = 7 # Automatically deletes logs after a week to save money
}

resource "aws_ecs_task_definition" "task_definition" {
  container_definitions = templatefile(
    "${path.module}/resources/ecs/task_definition.json",
    {
      container_name = "awsgoat-hr-app"
      image_uri      = var.ecs_image_uri
      rds_endpoint   = element(split(":", aws_db_instance.database-instance.endpoint), 0)
      s3_bucket_name = aws_s3_bucket.uploads_bucket.bucket
      log_group      = aws_cloudwatch_log_group.ecs_log_group.name
      aws_region     = "eu-central-1"
    }
  )
  family                   = "ECS-Lab-Task-definition"
  network_mode             = "bridge"
  memory                   = "512"
  cpu                      = "512"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.ecs-task-role.arn

  pid_mode = "host"
  volume {
    name      = "modules"
    host_path = "/lib/modules"
  }
  volume {
    name      = "kernels"
    host_path = "/usr/src/kernels"
  }
}




resource "aws_ecs_service" "worker" {
  name                              = "ecs_service_worker"
  cluster                           = aws_ecs_cluster.cluster.id
  task_definition                   = aws_ecs_task_definition.task_definition.arn
  desired_count                     = 1
  health_check_grace_period_seconds = 2147483647

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "awsgoat-hr-app"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.listener]
}

data "aws_elb_service_account" "main" {}

# Create the S3 Bucket for the ALB Logs
resource "aws_s3_bucket" "alb_logs_bucket" {
  bucket        = "aws-goat-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Useful for lab environments so Terraform can easily destroy it

  tags = {
    Name = "aws-goat-alb-logs"
  }
}

# Create the Bucket Policy allowing the ELB service to write to it
resource "aws_s3_bucket_policy" "alb_logs_bucket_policy" {
  bucket = aws_s3_bucket.alb_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        # Notice the structure here: it must match the prefix you set in the ALB block below
        Resource = "${aws_s3_bucket.alb_logs_bucket.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}

# trivy:ignore:AVD-AWS-0053
resource "aws_alb" "application_load_balancer" {
  name                       = "aws-goat-m2-alb"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_groups            = [aws_security_group.load_balancer_security_group.id]
  drop_invalid_header_fields = true

  # The configuration to activate logging
  access_logs {
    bucket  = aws_s3_bucket.alb_logs_bucket.id
    prefix  = "alb-logs"
    enabled = true
  }
  depends_on = [aws_s3_bucket_policy.alb_logs_bucket_policy]

  tags = {
    Name = "aws-goat-m2-alb"
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "aws-goat-m2-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.lab-vpc.id

  tags = {
    Name = "aws-goat-m2-tg"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  # Self Signed Certificate for testing purposes
  certificate_arn   = "arn:aws:acm:eu-central-1:675266034450:certificate/5c706098-18da-4d6d-bc7f-fded41a59a52"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id
  }
}


resource "aws_s3_bucket" "uploads_bucket" {
  bucket        = "aws-goat-m2-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "aws-goat-m2-uploads"
  }
}

resource "aws_s3_bucket_ownership_controls" "uploads_bucket_ownership" {
  bucket = aws_s3_bucket.uploads_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads_bucket_public_access" {
  bucket = aws_s3_bucket.uploads_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_iam_role_policy" "ecs-task-role-s3-policy" {
  name = "ecs-task-s3-access"
  role = aws_iam_role.ecs-task-role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.uploads_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "rds_creds" {
  name                    = "RDS_CREDS"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_creds.id
  secret_string = <<EOF
   {
    "username": "root",
    "password": "T2kVB3zgeN3YbrKS"
   }
EOF
}


output "ad_Target_URL" {
  value = "${aws_alb.application_load_balancer.dns_name}/login.php"
}

# Specific egress rules replacing 0.0.0.0/0
resource "aws_security_group_rule" "ecs_to_db_egress" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_sg.id
  source_security_group_id = aws_security_group.database-security-group.id
}

resource "aws_security_group_rule" "alb_to_ecs_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.load_balancer_security_group.id
  source_security_group_id = aws_security_group.ecs_sg.id
}

# Security group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC Endpoints"
  vpc_id      = aws_vpc.lab-vpc.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
}

resource "aws_security_group_rule" "ecs_to_endpoints_egress" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_sg.id
  source_security_group_id = aws_security_group.vpc_endpoints_sg.id
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.lab-vpc.id
  service_name = "com.amazonaws.eu-central-1.s3"
  route_table_ids = [aws_route_table.my_vpc_us_east_1_public_rt.id]
}

# Egress rule for S3 Gateway Endpoint (Prefix List)
resource "aws_security_group_rule" "ecs_to_s3_gateway_egress" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ecs_sg.id
  prefix_list_ids   = [aws_vpc_endpoint.s3.prefix_list_id]
}

# ECR API Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.lab-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

# ECR DKR Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.lab-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

# ECS Endpoint
resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = aws_vpc.lab-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

# ECS Agent Endpoint
resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id              = aws_vpc.lab-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecs-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

# ECS Telemetry Endpoint
resource "aws_vpc_endpoint" "ecs_telemetry" {
  vpc_id              = aws_vpc.lab-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

# CloudWatch Logs Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.lab-vpc.id
  service_name        = "com.amazonaws.eu-central-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.lab-subnet-public-1.id, aws_subnet.lab-subnet-public-1b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "aws-goat-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/main-trail"
  retention_in_days = 90 # Adjust based on your compliance needs
}

resource "aws_iam_role" "cloudtrail_cw_role" {
  name = "CloudTrail-CloudWatch-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw_policy" {
  name = "CloudTrail-CloudWatch-Policy"
  role = aws_iam_role.cloudtrail_cw_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        # Notice the :* at the end. CloudTrail requires this format to create streams.
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*" 
      }
    ]
  })
}

resource "aws_cloudtrail" "main_trail" {
  name                          = "aws-goat-main-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # CloudWatch Integration
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw_role.arn

  # CRITICAL: Wait for the bucket policy to be attached before creating the trail
  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}

# Create the S3 bucket for VPC Flow Logs
resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  bucket        = "aws-goat-vpc-flow-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "aws-goat-vpc-flow-logs"
  }
}

# Attach the Flow Log to the VPC and point it to S3
resource "aws_flow_log" "vpc_flow_log_s3" {
  log_destination      = aws_s3_bucket.vpc_flow_logs_bucket.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.lab-vpc.id

  tags = {
    Name = "VPC-Flow-Logs-S3"
  }
}

# Create the CloudWatch Log Group
resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 7 # Adjust based on your needs
}

# Create the IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "vpc-flow-log-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# Grant the role permission to write to CloudWatch
resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name = "vpc-flow-log-cw-policy"
  role = aws_iam_role.vpc_flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach the second Flow Log to the VPC and point it to CloudWatch
resource "aws_flow_log" "vpc_flow_log_cw" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.lab-vpc.id

  tags = {
    Name = "VPC-Flow-Logs-CloudWatch"
  }
}

# Create an Option Group to enable the Audit Plugin
resource "aws_db_option_group" "rds_audit_options" {
  name                 = "aws-goat-audit-options"
  engine_name          = "mysql"
  major_engine_version = "8.0"
  option_group_description = "Enable Audit logging for MySQL 8.0"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
    option_settings {
      name  = "SERVER_AUDIT_EVENTS"
      value = "CONNECT,QUERY" # Logs logins and queries
    }
  }
}

# Create a Parameter Group to enable General and Slow Query logs
resource "aws_db_parameter_group" "rds_logging_params" {
  name   = "aws-goat-db-parameters"
  family = "mysql8.0"
  description = "Enable General and Slow Query logging"

  parameter {
    name  = "general_log"
    value = "1"
  }
  
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  
  parameter {
    name  = "long_query_time"
    value = "2" # Logs any query taking longer than 2 seconds
  }
}

# Explicitly create the log groups to control retention
resource "aws_cloudwatch_log_group" "rds_audit_logs" {
  name              = "/aws/rds/instance/aws-goat-db/audit"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_error_logs" {
  name              = "/aws/rds/instance/aws-goat-db/error"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_general_logs" {
  name              = "/aws/rds/instance/aws-goat-db/general"
  retention_in_days = 7
}

# The S3 Bucket for Long-term RDS Log Storage
resource "aws_s3_bucket" "rds_logs_bucket" {
  bucket        = "aws-goat-rds-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# IAM Role for Firehose to write to S3
resource "aws_iam_role" "rds_firehose_role" {
  name = "rds-firehose-to-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "rds_firehose_policy" {
  name   = "rds-firehose-s3-policy"
  role   = aws_iam_role.rds_firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"]
      Effect   = "Allow"
      Resource = [aws_s3_bucket.rds_logs_bucket.arn, "${aws_s3_bucket.rds_logs_bucket.arn}/*"]
    }]
  })
}

# Create the Kinesis Firehose Stream
resource "aws_kinesis_firehose_delivery_stream" "rds_to_s3_stream" {
  name        = "rds-logs-to-s3"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.rds_firehose_role.arn
    bucket_arn = aws_s3_bucket.rds_logs_bucket.arn
    prefix     = "mysql-logs/"
  }
}

# IAM Role allowing CloudWatch to send data to Firehose
resource "aws_iam_role" "rds_cwl_to_firehose_role" {
  name = "rds-cwl-to-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "logs.eu-central-1.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "rds_cwl_to_firehose_policy" {
  name   = "rds-cwl-to-firehose-policy"
  role   = aws_iam_role.rds_cwl_to_firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
      Effect   = "Allow"
      Resource = aws_kinesis_firehose_delivery_stream.rds_to_s3_stream.arn
    }]
  })
}

# Connect the RDS CloudWatch Audit Logs to the Firehose Stream
resource "aws_cloudwatch_log_subscription_filter" "rds_audit_filter" {
  name            = "rds-audit-to-s3"
  role_arn        = aws_iam_role.rds_cwl_to_firehose_role.arn
  log_group_name  = aws_cloudwatch_log_group.rds_audit_logs.name
  filter_pattern  = "" # Captures everything
  destination_arn = aws_kinesis_firehose_delivery_stream.rds_to_s3_stream.arn
}


resource "aws_s3_bucket" "trail_uploads_bucket" {
  bucket        = "aws-goat-uploads-trail-storage-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "trail_uploads_bucket_policy" {
  bucket = aws_s3_bucket.trail_uploads_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.trail_uploads_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.trail_uploads_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "dedicated_trail_log_group" {
  name              = "/aws/cloudtrail/uploads-bucket-data-events"
  retention_in_days = 7
}

resource "aws_iam_role" "dedicated_trail_cw_role" {
  name = "aws-goat-uploads-trail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "dedicated_trail_cw_policy" {
  name = "aws-goat-uploads-trail-cw-policy"
  role = aws_iam_role.dedicated_trail_cw_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.dedicated_trail_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "uploads_data_trail" {
  name                          = "aws-goat-uploads-data-trail"
  s3_bucket_name                = aws_s3_bucket.trail_uploads_bucket.id
  include_global_service_events = false # Disabled to avoid duplicating management events
  is_multi_region_trail         = false # Can keep false if your bucket resides in only one region
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.dedicated_trail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.dedicated_trail_cw_role.arn

  # This selector intercepts ONLY S3 data actions on your specific bucket
  advanced_event_selector {
    name = "Log data events for the uploads bucket exclusively"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field       = "resources.ARN"
      # Points directly to the bucket contents. 
      # (Ensure aws_s3_bucket.uploads_bucket matches your exact local Terraform resource name)
      starts_with = ["${aws_s3_bucket.uploads_bucket.arn}/"] 
    }
  }

  # Ensure permissions are locked in before the trail attempts verification
  depends_on = [aws_s3_bucket_policy.trail_uploads_bucket_policy]
}

resource "aws_s3_bucket" "container_logs_bucket" {
  bucket        = "aws-goat-container-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# IAM Role allowing Firehose to write data into the new S3 bucket
resource "aws_iam_role" "firehose_container_role" {
  name = "aws-goat-firehose-container-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "firehose_container_s3_policy" {
  name = "firehose-container-s3-policy"
  role = aws_iam_role.firehose_container_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ]
      Resource = [
        aws_s3_bucket.container_logs_bucket.arn,
        "${aws_s3_bucket.container_logs_bucket.arn}/*"
      ]
    }]
  })
}

# The Firehose Delivery Stream using the AWS v5+ provider syntax
resource "aws_kinesis_firehose_delivery_stream" "container_to_s3_stream" {
  name        = "container-logs-to-s3"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_container_role.arn
    bucket_arn = aws_s3_bucket.container_logs_bucket.arn
    prefix     = "ecs-app-logs/"
  }
}

resource "aws_iam_role" "cwl_to_firehose_container_role" {
  name = "aws-goat-cwl-to-firehose-container-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cwl_to_firehose_container_policy" {
  name = "cwl-to-firehose-container-policy"
  role = aws_iam_role.cwl_to_firehose_container_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
      Resource = aws_kinesis_firehose_delivery_stream.container_to_s3_stream.arn
    }]
  })
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_logs_to_s3" {
  name            = "ecs-container-logs-to-s3-filter"
  role_arn        = aws_iam_role.cwl_to_firehose_container_role.arn
  log_group_name  = aws_cloudwatch_log_group.ecs_log_group.name # Points to your container log group
  filter_pattern  = "" # Blank means capture every single line (errors, status codes, crashes)
  destination_arn = aws_kinesis_firehose_delivery_stream.container_to_s3_stream.arn
}

# Athena requires a bucket to store the CSV results of your queries
resource "aws_s3_bucket" "athena_query_results" {
  bucket        = "aws-goat-athena-results-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Create an Athena Database (logical grouping for your tables)
resource "aws_athena_database" "lab_logs_db" {
  name   = "aws_goat_logs_db"
  bucket = aws_s3_bucket.athena_query_results.bucket
}

# Create an Athena Workgroup
resource "aws_athena_workgroup" "lab_workgroup" {
  name = "aws-goat-workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_query_results.bucket}/output/"
    }
  }
  force_destroy = true
}