# ------------------------------------------------------------------------------
# TERRAFORM / PROVIDER CONFIG
# ------------------------------------------------------------------------------

terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "gcs" {}
}

provider "google" {
  project     = "${var.project_id}"
  credentials = "${var.serviceaccount_key}"
}

# ------------------------------------------------------------------------------
# GOOGLE CLOUD PROJECT
# ------------------------------------------------------------------------------

resource "google_project_service" "services" {
  count = "${length(var.project_services)}"

  disable_on_destroy = false

  service = "${element(var.project_services, count.index)}"

  provisioner "local-exec" {
    command = "sleep 20"
  }
}

# ------------------------------------------------------------------------------
# Support for AuditConfigs is missing in terraform-provider-google
# GitHub issue:
# https://github.com/terraform-providers/terraform-provider-google/issues/936
# ------------------------------------------------------------------------------

# ...

# ------------------------------------------------------------------------------
# VPC NETWORK, SUBNETS, FIREWALL RULES
# ------------------------------------------------------------------------------

resource "google_compute_network" "network" {
  name                    = "network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnets" {
  count = "${length(var.cluster_subnets)}"

  name                     = "nodes"
  network                  = "${google_compute_network.network.self_link}"
  ip_cidr_range            = "${element(split(",", lookup(var.cluster_subnets, count.index)), 1)}"
  region                   = "${element(split(",", lookup(var.cluster_subnets, count.index)), 0)}"
  private_ip_google_access = true

  secondary_ip_range = [
    {
      range_name    = "pods"
      ip_cidr_range = "${element(split(",", lookup(var.cluster_subnets, count.index)), 2)}"
    },
    {
      range_name    = "services"
      ip_cidr_range = "${element(split(",", lookup(var.cluster_subnets, count.index)), 3)}"
    },
  ]
}

resource "google_compute_firewall" "allow_nodes_internal" {
  name        = "allow-nodes-internal"
  description = "Allow traffic between nodes"

  network  = "${google_compute_network.network.self_link}"
  priority = "65534"

  direction     = "INGRESS"
  source_ranges = ["${google_compute_subnetwork.subnets.*.ip_cidr_range}"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

resource "google_compute_firewall" "allow_pods_internal" {
  name     = "allow-pods-internal"
  network  = "${google_compute_network.network.name}"
  priority = "1000"

  description = "Allow traffic between pods and services"

  # services and pods ranges
  direction = "INGRESS"

  source_ranges = [
    "${google_compute_subnetwork.subnets.*.secondary_ip_range.0.ip_cidr_range}",
    "${google_compute_subnetwork.subnets.*.secondary_ip_range.1.ip_cidr_range}",
  ]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

# ------------------------------------------------------------------------------
# EXTERNAL IP ADDRESS
# ------------------------------------------------------------------------------

resource "google_compute_address" "ingress_controller_ip" {
  count = "${var.create_static_ip_address ? 1 : 0}"

  name         = "ingress-controller-ip"
  region       = "${var.static_ip_region}"
  address_type = "EXTERNAL"
}

# ------------------------------------------------------------------------------
# DNS ZONES AND RECORDS
# ------------------------------------------------------------------------------

resource "google_dns_managed_zone" "dns_zones" {
  count = "${length(var.dns_zones) > 0 ? length(var.dns_zones) : 0}"

  name     = "${element(keys(var.dns_zones), count.index)}"
  dns_name = "${element(values(var.dns_zones), count.index)}"
}

resource "google_dns_record_set" "dns_records" {
  count = "${length(var.dns_zones) > 0 && length(var.dns_records) > 0 ? length(var.dns_records) : 0}"

  type = "A"
  ttl  = 3600

  managed_zone = "${element(keys(var.dns_records), count.index)}"
  name         = "${element(values(var.dns_records), count.index)}"
  rrdatas      = ["${google_compute_address.ingress_controller_ip.0.address}"]
}
