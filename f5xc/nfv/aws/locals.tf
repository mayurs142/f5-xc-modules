locals {
  f5xc_tenant           = var.is_sensitive ? sensitive(var.f5xc_tenant) : var.f5xc_tenant
  f5xc_api_token        = var.is_sensitive ? sensitive(var.f5xc_api_token) : var.f5xc_api_token
  nfv_svc_get_uri       = format(var.f5xc_nfv_svc_get_uri, var.f5xc_namespace, var.f5xc_nfv_name)
  nfv_virtual_server_ip = (jsondecode(data.http.nfv_virtual_server_ip.response_body).status[*].vip)[0]
}