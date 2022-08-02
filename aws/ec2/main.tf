resource "aws_key_pair" "aws-key" {
  key_name   = format("%s-key", var.aws_ec2_instance_name)
  public_key = file(format("%s/keys/%s", path.module, var.ssh_public_key_file))
}

resource "aws_security_group" "public" {
  name   = format("%s-public-sg", var.aws_ec2_instance_name, )
  vpc_id = var.aws_vpc_workload_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Owner = var.owner_tag
  }
}

resource "aws_security_group" "private" {
  name   = format("%s-private-sg", var.aws_ec2_instance_name)
  vpc_id = var.aws_vpc_workload_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.16.0.0/16"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/16"]
  }

  tags = {
    Owner = var.owner_tag
  }
}

resource "aws_network_interface" "public" {
  subnet_id       = var.aws_subnet_public_id
  private_ips     = var.aws_ec2_public_ips
  security_groups = [aws_security_group.public.id]

  tags = {
    Owner = var.owner_tag
  }
}

resource "aws_network_interface" "private" {
  subnet_id       = var.aws_subnet_private_id
  private_ips     = var.aws_ec2_private_ips
  security_groups = [aws_security_group.private.id]

  tags = {
    Owner = var.owner_tag
  }
}

resource "aws_eip" "eip" {
  vpc               = true
  network_interface = aws_network_interface.public.id

  tags = {
    Owner = var.owner_tag
  }
}

resource "aws_instance" "instance" {
  ami                         = lookup(var.amis, var.aws_region)
  instance_type               = var.aws_ec2_instance_type
  key_name                    = aws_key_pair.aws-key.id
  user_data_replace_on_change = true

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.public.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.private.id
  }

  tags = {
    Name        = var.aws_ec2_instance_name
    Environment = var.environment
    Version     = "1"
    Owner       = var.owner_tag
  }
}

resource "local_file" "payload" {
  depends_on = [aws_instance.instance]
  content    = local.userdata_content
  filename   = format("%s/_out/%s", path.module, var.aws_ec2_instance_script_file)
}

resource "null_resource" "ec2_instance_provision_custom_files" {
  depends_on = [aws_instance.instance, local_file.payload]
  for_each   = {for item in var.aws_ec2_instance_userdata_dirs : item.name => item}

  /*triggers = {
    always_run = timestamp()
  }*/

  connection {
    type        = "ssh"
    host        = aws_eip.eip.public_ip
    user        = "ubuntu"
    private_key = file(format("%s/keys/%s", path.module, var.ssh_private_key_file))
  }

  provisioner "file" {
    source      = each.value.source
    destination = each.value.destination
  }
}

resource "null_resource" "ec2_provision_script_file" {
  depends_on = [null_resource.ec2_instance_provision_custom_files]
  connection {
    type        = "ssh"
    host        = aws_eip.eip.public_ip
    user        = "ubuntu"
    private_key = file(format("%s/keys/%s", path.module, var.ssh_private_key_file))
  }

  provisioner "remote-exec" {
    inline = var.aws_ec2_instance_data.inline
  }
}