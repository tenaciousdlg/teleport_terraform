output "db_name" {
  value = teleport_database.mysql.metadata["name"]
}