# outputs.tf

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.myapp_server.public_ip
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.myapp_vpc.id
}

output "subnet_id" {
  description = "ID of the created Subnet"
  value       = aws_subnet.myapp_subnet.id
}

output "security_group_id" {
  description = "ID of the created Security Group"
  value       = aws_security_group.myapp_sg.id
}
