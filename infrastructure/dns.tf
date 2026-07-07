resource "aws_route53_zone" "main" {
  name = "catapultwelcomebonus.xyz"

  tags = {
    Name = "catapultwelcomebonus-zone"
  }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.catapultwelcomebonus.xyz"
  type    = "A"
  ttl     = 300
  records = [aws_eip.ips_eip.public_ip]
}
