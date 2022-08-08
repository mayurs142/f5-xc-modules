resource "volterra_aws_tgw_site" "tgw" {
  name                    = var.f5xc_aws_tgw_name
  namespace               = var.f5xc_namespace
  logs_streaming_disabled = var.f5xc_aws_tgw_logs_streaming_disabled
  lifecycle {
    ignore_changes = [labels, description]
  }
  os {
    default_os_version       = var.f5xc_aws_default_ce_os_version
    operating_system_version = local.f5xc_aws_ce_os_version
  }
  sw {
    default_sw_version        = var.f5xc_aws_default_ce_sw_version
    volterra_software_version = local.f5xc_aws_ce_sw_version
  }
  tags = var.custom_tags

  aws_parameters {
    aws_certified_hw = var.f5xc_aws_certified_hw
    aws_region       = var.f5xc_aws_region

    dynamic "az_nodes" {
      for_each = var.f5xc_aws_tgw_id == "" && var.f5xc_aws_tgw_primary_ipv4 != "" ? var.f5xc_aws_tgw_az_nodes : {}
      content {
        aws_az_name = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_az_name"]
        disk_size   = var.f5xc_aws_tgw_ce_instance_disk_size

        workload_subnet {
          subnet_param {
            ipv4 = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_workload_subnet"]
          }
        }

        dynamic "inside_subnet" {
          for_each = contains(keys(var.f5xc_aws_tgw_az_nodes[az_nodes.key]), "f5xc_aws_tgw_inside_subnet") ? [1] : []
          content {
            subnet_param {
              ipv4 = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_inside_subnet"]
            }
          }
        }

        outside_subnet {
          subnet_param {
            ipv4 = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_outside_subnet"]
          }
        }
      }
    }

    dynamic "az_nodes" {
      for_each = var.f5xc_aws_tgw_id != "" && var.f5xc_aws_tgw_primary_ipv4 == "" ? var.f5xc_aws_tgw_az_nodes : {}
      content {
        aws_az_name = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_az_name"]
        disk_size   = var.f5xc_aws_tgw_ce_instance_disk_size

        workload_subnet {
          existing_subnet_id = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_workload_existing_subnet_id"]
        }

        dynamic "inside_subnet" {
          for_each = contains(keys(var.f5xc_aws_tgw_az_nodes[az_nodes.key]), "f5xc_aws_tgw_inside_existing_subnet_id") ? [1] : []
          content {
            existing_subnet_id = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_inside_existing_subnet_id"]
          }
        }

        outside_subnet {
          existing_subnet_id = var.f5xc_aws_tgw_az_nodes[az_nodes.key]["f5xc_aws_tgw_outside_existing_subnet_id"]
        }
      }
    }

    aws_cred {
      name      = var.f5xc_aws_cred
      namespace = var.f5xc_namespace
      tenant    = var.f5xc_tenant
    }
    instance_type = var.f5xc_aws_tgw_instance_type

    dynamic "new_vpc" {
      for_each = var.f5xc_aws_vpc_id == "" && var.f5xc_aws_tgw_primary_ipv4 != "" ? [1] : []
      content {
        allocate_ipv6 = var.f5xc_aws_tgw_vpc_allocate_ipv6
        autogenerate  = var.f5xc_aws_tgw_vpc_autogenerate
        primary_ipv4  = var.f5xc_aws_tgw_primary_ipv4
      }
    }

    vpc_id = var.f5xc_aws_vpc_id != "" && var.f5xc_aws_tgw_primary_ipv4 == "" ? var.f5xc_aws_vpc_id : null

    dynamic "existing_tgw" {
      for_each = var.f5xc_aws_tgw_asn != "" && var.f5xc_aws_tgw_id != "" && var.f5xc_aws_tgw_site_asn != "" ? [1] : [0]
      content {
        tgw_asn           = var.f5xc_aws_tgw_asn
        tgw_id            = var.f5xc_aws_tgw_id
        volterra_site_asn = var.f5xc_aws_tgw_site_asn
      }
    }

    dynamic "new_tgw" {
      for_each = var.f5xc_aws_tgw_asn == "" && var.f5xc_aws_tgw_id == "" && var.f5xc_aws_tgw_site_asn == "" ? [1] : [0]
      content {
        system_generated = var.f5xc_aws_tgw_vpc_system_generated
      }
    }

    no_worker_nodes = var.f5xc_aws_tgw_no_worker_nodes
    nodes_per_az    = var.f5xc_aws_tgw_worker_nodes_per_az > 0 ? var.f5xc_aws_tgw_worker_nodes_per_az : null
    total_nodes     = var.f5xc_aws_tgw_total_worker_nodes > 0 ? var.f5xc_aws_tgw_total_worker_nodes : null
    ssh_key         = var.public_ssh_key
  }

  dynamic "vpc_attachments" {
    for_each = length(var.f5xc_aws_vpc_attachment_ids) > 0 ? [1] : []
    content {
      dynamic "vpc_list" {
        for_each = var.f5xc_aws_vpc_attachment_ids
        content {
          labels = {
            "deployment" = var.f5xc_aws_tgw_vpc_attach_label_deploy
          }
          vpc_id = vpc_list.value
        }
      }
    }
  }
}

resource "volterra_cloud_site_labels" "labels" {
  name             = volterra_aws_tgw_site.tgw.name
  site_type        = "aws_vpc_site"
  # need at least one label, otherwise site_type is ignored
  labels           = merge({ "key" = "value" }, var.custom_tags)
  ignore_on_delete = true
}

resource "volterra_tf_params_action" "aws_tgw_action" {
  site_name       = volterra_aws_tgw_site.tgw.name
  site_kind       = var.f5xc_site_kind
  action          = var.f5xc_tf_params_action
  wait_for_action = var.f5xc_tf_wait_for_action
}