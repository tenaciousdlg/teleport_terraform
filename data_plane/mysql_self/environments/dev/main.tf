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

module "mysql_dev" {
  source = "../../modules/teleport_mysql"

  env                = "dev"
  user               = "internal-dev"
  proxy_address      = "proxy.teleportdemo.com"
  teleport_version   = "16.0.0"
  teleport_db_ca     = data.http.teleport_db_ca_cert.response_body
  mysql_hostname     = "mysql.dev.internal"
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = "t3.small"
  subnet_id          = "subnet-xxxxxxxx"
  security_group_ids = ["sg-xxxxxxxx"]
}