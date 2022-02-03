module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.name}-vpc"
  cidr = var.cidr

  azs             = var.azs
  public_subnets = var.public_subnets
  enable_nat_gateway = var.enable_nat_gateway
  database_subnets = var.database_subnets
  create_database_subnet_route_table = var.create_database_subnet_route_table
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group

resource "aws_security_group" "sg_public" {
  name        = "sg_public"
  description = "Allow port 22, 80, 443"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["108.56.137.235/32"]
  }

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    description      = "allow all egress rule"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "sg_private" {
  name        = "sg_private"
  description = "Allow port 22, 80, 443, and 3306"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["108.56.137.235/32"]
  }

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    security_groups   = tolist(["${aws_security_group.sg_public.id}"])
  }
  
  ingress {
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    security_groups   = tolist(["${aws_security_group.sg_public.id}"])
  }

  ingress {
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = tolist(["${aws_security_group.sg_public.id}"])
  }
  
  egress {
    description      = "allow all egress rule"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

module "web-ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"
  name = "${var.name}-web"
  ami                    = var.ami
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = tolist(["${aws_security_group.sg_public.id}"])
  subnet_id              = module.vpc.public_subnets[0]
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
depends_on = [module.vpc]  
}

module "db-ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"
  name = "${var.name}-db"
  ami                    = var.ami
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = tolist(["${aws_security_group.sg_private.id}"])
  subnet_id              = module.vpc.database_subnets[0]
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

depends_on = [module.vpc]  
}