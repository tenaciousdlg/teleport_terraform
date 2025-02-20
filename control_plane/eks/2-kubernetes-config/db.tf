resource "aws_db_instance" "teleport_postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.6"
  instance_class       = "db.t3.micro"
  db_name              = "teleportdb"
  username             = var.db_username
  password             = var.db_password
  publicly_accessible  = false
  skip_final_snapshot  = true
  vpc_security_group_ids = [module.vpc.default_security_group_id]

  # Ensure the subnet group aligns with your EKS VPC
  db_subnet_group_name = module.vpc.database_subnet_group_name
}
