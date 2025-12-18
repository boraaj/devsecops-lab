output "server_public_ip" {
    description = "Public IP allowed for resource access"
    value       = aws_instance.k3s_server.public_ip
}

output "dynamodb_table_name" {
    description = "DynamoDB Table Name"
    value       = aws_dynamodb_table.app_table.name
}

output "ssm_connect_command" {
    description = "AWS CLI connection command (requires Session Manager plugin)"
    value       = "aws ssm start-session --target ${aws_instance.k3s_server.id}"
}

output "debug_ubuntu_name" {
    value       = data.aws_ami.ubuntu.name
}

output "ecr_repository_url"{
    value = aws_ecr_repository.app_repo.repository_url
}