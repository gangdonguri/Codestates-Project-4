resource "aws_iam_role" "ssm_role" {
  name = "SSMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_role.name
}



resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_eip" "vpn_eip" {
  instance = aws_instance.vpn_instance.id
}

resource "aws_eip_association" "vpn_eip_assoc" {
  instance_id   = aws_instance.vpn_instance.id
  allocation_id = aws_eip.vpn_eip.id
}




resource "aws_instance" "vpn_instance" {
  ami                         = var.vpn_ami
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  subnet_id                   = module.network.public_subnet_id[0]
  key_name                    = "myKey"
  associate_public_ip_address = "true"
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  user_data                   = <<-EOF
               #!/bin/bash
              sudo yum install -y amazon-ssm-agent
              sudo systemctl enable amazon-ssm-agent
              sudo systemctl start amazon-ssm-agent
              EOF

  tags = {
    Name = "final-vpn-1"
  }
}

resource "aws_cloudwatch_log_group" "session_log_group" {
  name = "/aws/ssm/final-test"
}

resource "aws_ssm_maintenance_window_task" "ssesion_manager_task" {
  task_type       = "RUN_COMMAND"
  max_concurrency = "50"
  max_errors      = "0"
  targets {
    key   = "InstanceIds"
    value = [aws_instance.vpn_instance.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      document_name = "AWS-StartSession"
      comment       = "Start session"
      parameters = {
        "CloudWatchLogGroupName"      = "${aws_cloudwatch_log_group.session_log_group.name}"
        "CloudWatchEncryptionEnabled" = "false"
      }
    }
  }
}
