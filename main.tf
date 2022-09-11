terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = "terraform"
}

# VPC Input Variables

# VPC CIDR Block
variable "vpc_cidr_block" {
  description = "Please enter the IP range (CIDR notation) for this VPC"
  type        = string
  default     = "10.192.0.0/16"
}

variable "vpc_public_subnets" {
  description = "VPC Public Subnets"
  type        = list(string)
  default     = ["10.192.10.0/24", "10.192.11.0/24"]
}

# VPC Private Subnets
variable "vpc_private_subnets" {
  description = "VPC Private Subnets"
  type        = list(string)
  default     = ["10.192.20.0/24", "10.192.21.0/24"]
}
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Environment Variable
variable "EnvironmentName" {
  description = "Environment Variable used as a prefix"
  type        = list(string)
  default     = ["dev", "prod", "stage"]
}

variable "availability_zone" {
  description = "Mapping of Availabilty Zones"
  type        = map(any)
  default = {
    "az-1" = "us-east-1a"
    "az-2" = "us-east-1b"
  }
}


################ VPC ##########################

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_block
  # VPC DNS Parameters
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.EnvironmentName[0]}"
  }
}

###################### PUBLIC SUBNETS ########################

resource "aws_subnet" "PublicSubnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.vpc_public_subnets[0]
  availability_zone       = var.availability_zone["az-1"]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.EnvironmentName[0]}-PublicSubnet-${var.availability_zone["az-1"]}"
  }
}


resource "aws_subnet" "PublicSubnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.vpc_public_subnets[1]
  availability_zone       = var.availability_zone["az-2"]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.EnvironmentName[0]}-PublicSubnet-${var.availability_zone["az-2"]}"
  }
}

############################# PRIVATE SUBNETS ########################

resource "aws_subnet" "PrivateSubnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.vpc_private_subnets[0]
  availability_zone       = var.availability_zone["az-1"]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.EnvironmentName[0]}-PrivateSubnet-${var.availability_zone["az-1"]}"
  }
}


resource "aws_subnet" "PrivateSubnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.vpc_private_subnets[1]
  availability_zone       = var.availability_zone["az-2"]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.EnvironmentName[0]}-PrivateSubnet-${var.availability_zone["az-2"]}"
  }
}

################################### INTERNET GATEWAY #########################

resource "aws_internet_gateway" "InternetGateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.EnvironmentName[0]}"
  }
}

############################## ELASTIC IP ##############################

resource "aws_eip" "NatGateway1EIP" {
  vpc = true
}

resource "aws_eip" "NatGateway2EIP" {
  vpc = true
}

##################################### NAT GATEWAY ###############################

resource "aws_nat_gateway" "NatGateway1" {
  allocation_id = aws_eip.NatGateway1EIP.id
  subnet_id     = aws_subnet.PrivateSubnet1.id
}

resource "aws_nat_gateway" "NatGateway2" {
  allocation_id = aws_eip.NatGateway2EIP.id
  subnet_id     = aws_subnet.PrivateSubnet2.id
}

################################ PUBLIC ROUTE TABLE ##############################

resource "aws_route_table" "PublicRouteTable" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.InternetGateway.id
  }
  tags = {
    Name = "${var.EnvironmentName[0]}-publicRoutes"
  }
}
#################################### PUBLIC SUBNET ROUTETABLE ASSOCIATION  ############################

resource "aws_route_table_association" "PublicSubnet1RouteTableAssociation" {
  subnet_id      = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.PublicRouteTable.id
}


resource "aws_route_table_association" "PublicSubnet2RouteTableAssociation" {
  subnet_id      = aws_subnet.PublicSubnet2.id
  route_table_id = aws_route_table.PublicRouteTable.id
}

################################ PRIVATE ROUTE TABLE ##############################
resource "aws_route_table" "PrivateRouteTable1" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NatGateway1.id
  }
}

#################################### PRIVATE SUBNET ROUTETABLE ASSOCIATION  ############################
resource "aws_route_table_association" "PrivateSubnet1RouteTableAssociation" {
  subnet_id      = aws_subnet.PrivateSubnet1.id
  route_table_id = aws_route_table.PrivateRouteTable1.id
}


resource "aws_route_table" "PrivateRouteTable2" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NatGateway2.id
  }
}
resource "aws_route_table_association" "PrivateSubnet2RouteTableAssociation" {
  subnet_id      = aws_subnet.PrivateSubnet2.id
  route_table_id = aws_route_table.PrivateRouteTable2.id
}

########################### SECURITY GROUP #########################
resource "aws_security_group" "NoIngressSecurityGroup" {
  name        = "no-ingress-sg"
  description = "Security group with no ingress rule"
  vpc_id      = aws_vpc.vpc.id
}


############################ OUTPUTS ###############################

output "VPC" {
  value = aws_vpc.vpc.id
}

output "PublicSubnets" {
  value = join(", ", ["${aws_subnet.PublicSubnet1.id}", "${aws_subnet.PublicSubnet2.id}"])
}

output "PrivateSubnets" {
  value = join(", ", ["${aws_subnet.PrivateSubnet1.id}", "${aws_subnet.PrivateSubnet2.id}"])
}


output "PublicSubnet1" {
  value = aws_subnet.PublicSubnet1.id
}
output "PublicSubnet2" {
  value = aws_subnet.PublicSubnet2.id
}
output "PrivateSubnet1" {
  value = aws_subnet.PrivateSubnet1.id
}
output "PrivateSubnet2" {
  value = aws_subnet.PrivateSubnet2.id
}
output "NoIngressSecurityGroup" {
  value = aws_security_group.NoIngressSecurityGroup.id
}
