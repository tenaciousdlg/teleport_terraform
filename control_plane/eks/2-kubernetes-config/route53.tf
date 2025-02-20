# used for creating subdomain on existing zone. zone is defined by the variable domain_name
data "aws_route53_zone" "main" {
  name = var.domain_name
}

# creates DNS record for teleport cluster on eks
resource "aws_route53_record" "cluster_endpoint" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.cluster_name
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}

# creates wildcard record for teleport cluster on eks 
resource "aws_route53_record" "wild_cluster_endpoint" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.cluster_name}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}