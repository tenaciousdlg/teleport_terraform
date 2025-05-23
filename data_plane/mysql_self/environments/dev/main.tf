module "mysql_instance" {
  source              = "../../modules/teleport_mysql_instance"
  env                 = var.env
  user                = var.user
  proxy_address       = var.proxy_address
  teleport_version    = var.teleport_version
  teleport_db_ca      = data.http.teleport_db_ca_cert.response_body
  ami_id              = data.aws_ami.ubuntu.id
  instance_type       = "t3.small"
  subnet_id           = var.subnet_id
  security_group_ids  = [var.security_group_id]
}

module "mysql_registration" {
  source          = "../../modules/teleport_mysql_registration"
  env             = var.env
  uri             = "localhost:3306"
  ca_cert_chain   = module.mysql_instance.ca_cert
  labels = {
    tier = var.env
  }
}