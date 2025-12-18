# 1 Creating Role for 
resource "aws_iam_role" "ec2_role" {
  name = "devsecops_lab_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 2. Permission for SSM
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. OLD POLICY - Adding DynamoDB permission (Only Read/Write specific)
# resource "aws_iam_role_policy_attachment" "dynamo_policy" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
# }

# Least Privilege Principle
resource "aws_iam_role_policy" "dynamo_least_privilege" {
  name = "dynamodb-scoped-access"
  role = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ]
      # Only Access to the table created by Terraform
      Resource = aws_dynamodb_table.app_table.arn 
    }]
  })

}

# 4. Creating "Instance Profile" (el contenedor del rol para la EC2)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devsecops_lab_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_policy_attachment" "ecr_read_policy" {
  name = "ecr_read_policy"
  roles = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}