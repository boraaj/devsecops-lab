# --- DYNAMODB (Serverless DB) ---

resource "aws_dynamodb_table" "app_table" {
  name         = "devsecops-items"
  billing_mode = "PAY_PER_REQUEST" # Only Pay per Request
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String
  }

  lifecycle{
    prevent_destroy = false # Prevents from using Terraform Destroy. 
  }

  tags = {
    Environment = "Dev"
    Project     = "DevSecOps-Lab"
  }
}

# --- SECURITY GROUP (Firewall) ---
# Following the last Terraform standards, I'll create an empty SG and then I'll put the rules inside separately. This avoids using inline rules and presents a more modular strategy.  
# More info here => https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security Group for Web Traffic"

  tags = {
    Name = "web-sg"
  }
}

# Rule Allow Inbound HTTP
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.web_sg.id

  cidr_ipv4   = var.allowed_ingress_ip
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

# Rule Allow Outbound HTTP
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.web_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # -1 = All protocols
}

## Data for the EC2 Instance ##
data "aws_ami" "ubuntu"{

    most_recent = true # Allows AWS to download security patches. More info Here https://dev.to/1suleyman/stop-hardcoding-amis-use-terraform-to-automatically-fetch-the-latest-os-image-42af
    owners = ["099720109477"] # Canonical ID 

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

}

# --- EC2 INSTANCE (K3s Node) ---
resource "aws_instance" "k3s_server" {
  ami           = data.aws_ami.ubuntu.id 
  instance_type = var.instance_type              # Free tier eligible

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "${var.project_name}-Server"
    Project = var.project_name
  }
  
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              # 1. Update system
              apt-get update -y
              
              #2 Installs k3s and containerd, a lightweoigth version of Docker. & Disabling taefik controller and metrics for saving space. 
              curl -sfL https://get.k3s.io | sh -s - --disable traefik --disable metrics-server
              
              sleep 10

              #3 User docker creation
              #usermod -aG docker ubuntu

              #4 ssm user creation
              id -u ssm-user &>/dev/null || useradd -m -s /bin/bash ssm-user
              
              # SECURITY 

              # A allow sudo without password (As I use IAM user to connections)
              echo 'ssm-user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ssm-user
              chmod 0440 /etc/sudoers.d/ssm-user

              # B Docker Containerd configuration for k3s
              usermod -aG docker ssm-user

              # C kubeconfig for not using sudo
              mkdir -p /home/ssm-user/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ssm-user/.kube/config

              chown -R ssm-user:ssm-user /home/ssm-user
              chmod 600 /home/ssm-user/.kube/config

              # For debuging reasons
              chmod 644 /etc/rancher/k3s/k3s.yaml

              echo 'export KUBECONFIG=/home/ssm-user/.kube/config' >> /home/ssm-user/.bashrc
              echo 'alias k=kubectl' >> /home/ssm-user/.bashrc
              EOF
}

# --- ECR (Docker Registry) ---

resource "aws_ecr_repository" "app_repo" {
  name = "devsecops-app"
  image_tag_mutability = "MUTABLE"
  force_delete = true # allows to destroy de repo with terraform destroy even if it contains images

  image_scanning_configuration {
    scan_on_push = true # Enables to Scanner the image after push.
  }

  tags = {
    project_name = var.project_name
  }
}

# ECR policy to cleanup repositories and leave only the last 2 images. 
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description = "Only retain the last 2 images"
      selection = {
        tagStatus = "any"
        countType = "imageCountMoreThan"
        countNumber = 2
      }
      action = {
        type = "expire"
      }
    }]
  })
}