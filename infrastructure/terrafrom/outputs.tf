output "app_public_ip" {
  description = "Public IP of the app EC2 instance"
  value       = aws_eip.web_eip.public_ip
}


