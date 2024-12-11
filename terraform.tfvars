# CIDR block for the VPC
vpc_cidr_block = "10.0.0.0/16"

# List of CIDR blocks for subnets
subnet_cidr_block = [
  "10.0.0.0/19",
  "10.0.32.0/19"
]

# Availability zone for resources
avail_zone = "us-east-1a"

# Prefix for environment-specific resource naming
env_prefix = "dev"

# Your IP address for SSH access (CIDR block format)
# Note: /32 denotes a single IP address.
# Example: myip = "<server-ip>/32"
myip = "0.0.0.0/0" # Caution: This allows access from anywhere; restrict in production.

# EC2 instance type
ec2-type = "t2.micro"

# Path to the public key file for EC2 instance SSH access
public-key-location = "/home/ec2-user/.ssh/test.pub"


/*

# Old for future reference purpose only 
vpc_cidr_block = "10.0.0.0/16"
subnet_cidr_block = ["10.0.0.0/19", "10.0.32.0/19"]
avail_zone = "us-east-1a"
env_prefix = "dev"
// myip = <server-ip>/32  --> this /32 means one single ip. as its cidr block so we have to use /32 
myip = "0.0.0.0/0"
ec2-type = "t2.micro"
public-key-location = "/home/ec2-user/.ssh/test.pub"

*/