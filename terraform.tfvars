vpc_cidr_block = "10.0.0.0/16"
subnet_cidr_block = ["10.0.0.0/19", "10.0.32.0/19"]
avail_zone = "us-east-1a"
env_prefix = "dev"
// myip = <server-ip>/32  --> this /32 means one single ip. as its cidr block so we have to use /32 
myip = "<server-ip>/32"
ec2-type = "t2.micro"
public-key-location = "/user/home/.ssh/id_rsa.pub"