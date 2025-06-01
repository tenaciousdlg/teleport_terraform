module "httpbin_app" {
  source           = "../../modules/app_httpbin"
  env              = var.env
  user             = var.user
  proxy_address    = var.proxy_address
  teleport_version = var.teleport_version
}

module "httpbin_registration" {
  source        = "../../modules/registration"
  resource_type = "app"
  name          = "httpbin-${var.env}"
  description   = "Internal HTTP test app using httpbin"
  uri           = "http://localhost:80"
  public_addr   = "httpbin-${var.env}.${var.proxy_address}"
  labels = {
    tier               = var.env
    "teleport.dev/app" = "httpbin"
  }
  rewrite_headers = [
    "Host: httpbin-${var.env}.${var.proxy_address}",
    "Origin: https://httpbin-${var.env}.${var.proxy_address}"
  ]
  insecure_skip_verify = true
}
