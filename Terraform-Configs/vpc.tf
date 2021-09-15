variable "region" {
    default = "us-east-1"
}

data "aws_availability_zones" "available" {}

locals {
    cluster_name = "EKS-Cluster"
}

module vpc {
    source = "terraform-aws-modules/vpc/aws"
    version = "3.2.0"
    name = "Demo-VPC"
    cidr = "10.0.0.0/16"
    azs = data.aws_availability_zones.available.names
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets =  ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    enable_nat_gateway = true
    single_nat_gateway = true
    enable_dns_hostname = true

tags = {
    "Name" = "Demo-VPC"
}

public_subnet_tags = {
    "Name" = "Demo-Public-Subnet"
}

private_subnet_tags = {
    "Name" = "Demo-Private-Subnet"
}
}