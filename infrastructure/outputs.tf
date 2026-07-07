output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ips_server.id
}

output "eip_public_ip" {
  description = "Static public IP (Elastic IP) — use this for DNS, iOS app, and SSH"
  value       = aws_eip.ips_eip.public_ip
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.ips_vpc.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.ips_public_subnet.id
}

output "state_bucket_name" {
  description = "S3 bucket holding remote Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "route53_nameservers" {
  description = "Route 53 nameservers — copy these into Namecheap custom DNS"
  value       = aws_route53_zone.main.name_servers
}
