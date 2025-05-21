data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "http" "teleport_db_ca_cert" {
  url = "https://proxy.teleportdemo.com/webapi/auth/export?type=db-client"
}

module "mysql_prod" {
  source = "../../modules/teleport_mysql"

  env                = "prod"
  user               = "internal-prod"
  proxy_address      = "proxy.teleportdemo.com"
  teleport_version   = "16.0.0"
  teleport_db_ca     = data.http.teleport_db_ca_cert.response_body
  mysql_hostname     = "mysql.prod.internal"
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = "t3.medium"
  subnet_id          = "subnet-yyyyyyyy"
  security_group_ids = ["sg-yyyyyyyy"]
}
