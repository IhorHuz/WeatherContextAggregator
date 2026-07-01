terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ips-terraform-state-232025405481-eu-central-1"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-central-1"
    profile        = "ips-dev"
    dynamodb_table = "ips-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "ips-dev"
}

resource "aws_key_pair" "ips_key" {
  key_name   = "ips-ec2-key"
  public_key = file(var.public_key_path)
}

resource "aws_vpc" "ips_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ips-vpc"
  }
}

resource "aws_internet_gateway" "ips_igw" {
  vpc_id = aws_vpc.ips_vpc.id

  tags = {
    Name = "ips-igw"
  }
}

resource "aws_subnet" "ips_public_subnet" {
  vpc_id                  = aws_vpc.ips_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "ips-public-subnet"
  }
}

resource "aws_route_table" "ips_rt" {
  vpc_id = aws_vpc.ips_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ips_igw.id
  }

  tags = {
    Name = "ips-rt"
  }
}

resource "aws_route_table_association" "ips_rta" {
  subnet_id      = aws_subnet.ips_public_subnet.id
  route_table_id = aws_route_table.ips_rt.id
}

resource "aws_security_group" "ips_sg" {
  name   = "ips-sg"
  vpc_id = aws_vpc.ips_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ips-sg"
  }
}

resource "aws_eip" "ips_eip" {
  domain = "vpc"

  tags = {
    Name = "ips-eip"
  }
}

resource "aws_eip_association" "ips_eip_assoc" {
  instance_id   = aws_instance.ips_server.id
  allocation_id = aws_eip.ips_eip.id
}

resource "aws_instance" "ips_server" {
  ami                    = "ami-0a628e1e89aaedf80"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.ips_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ips_sg.id]
  key_name               = aws_key_pair.ips_key.key_name

  user_data = <<EOF
#!/bin/bash
set -euxo pipefail

apt-get update -qq
apt-get upgrade -y -qq

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker ubuntu

# ── Clone and build the app ──
cd /opt
git clone https://github.com/IhorHuz/WeatherContextAggregator.git
cd WeatherContextAggregator/backend
docker build -t wca:latest .
docker run -d \
  --restart unless-stopped \
  -p 8081:8000 \
  --name wca \
  wca:latest

# ── Nginx reverse proxy with self-signed SSL ──
apt-get install -y -qq nginx
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/ips.key \
  -out /etc/nginx/ssl/ips.crt \
  -subj "/C=DE/ST=Berlin/L=Berlin/O=IPS/CN=${public_ip}" 2>/dev/null

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/ips << 'NGINX'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name _;
    ssl_certificate /etc/nginx/ssl/ips.crt;
    ssl_certificate_key /etc/nginx/ssl/ips.key;
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX
ln -sf /etc/nginx/sites-available/ips /etc/nginx/sites-enabled/
systemctl enable --now nginx
ufw allow https
EOF

  tags = {
    Name = "ips-server"
  }
}