terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  credentials = file("C:/Users/gusta/Desktop/ProjetoGCP/proven-mind-419419-0bee905857f9.json")
  project     = "proven-mind-419419"
  region      = "us-central1"
}

resource "google_compute_network" "vpc" {
  name                    = "minha-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnetwork" {
  name          = "subrede-privada"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
}

resource "google_compute_router" "router" {
  name    = "meu-router"
  region  = "us-central1"
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat_ip" {
  name   = "meu-ip-nat"
  region = "us-central1"
}

resource "google_compute_router_nat" "nat" {
  name                               = "meu-nat"
  router                             = google_compute_router.router.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_all" {
  name    = "allow-all"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "default" {
  depends_on = [
    google_compute_subnetwork.private_subnetwork,
    google_compute_network.vpc
  ]
  
  name         = "sentry-vm"
  machine_type = "e2-standard-4"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "imagevmsentry"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.private_subnetwork.name
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("C:/Users/gusta/Desktop/ProjetoGCP/id_rsa.pub")}"
  }
}

resource "google_container_cluster" "primary" {
  name     = "meu-cluster-gke"
  location = "us-central1"

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptive_nodes" {
  name       = "meu-node-pool-preemptivo"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  repository = "https://sonarsource.github.io/helm-chart-sonarqube" // Repositório atualizado
  chart      = "sonarqube"
  version    = "10.4.1" // Versão mais recente disponível

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.externalPort"
    value = "80"
  }
}

resource "google_cloudbuild_trigger" "whalesay_trigger" {
  project = "proven-mind-419419"
  name = "whalesay-trigger"
  description = "Trigger para whalesay job"
  filename = "cloudbuild.yaml"
  included_files = [
    "cloudbuild.yaml"
  ]

  trigger_template {
    project_id = "proven-mind-419419"
    repo_name = "Drogon"
    branch_name = "master"
  }
}

resource "google_cloud_scheduler_job" "whalesay_scheduler" {
  name        = "whalesay-scheduler"
  description = "A cada 5 minutos dispara o Cloud Build para executar o whalesay job no GKE"
  schedule    = "*/5 * * * *"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/proven-mind-419419/locations/global/triggers/${google_cloudbuild_trigger.whalesay_trigger.id}:run"
    body        = base64encode("{}")
    oauth_token {
      service_account_email = "gribeiro@proven-mind-419419.iam.gserviceaccount.com"
    }
  }
}

resource "google_logging_metric" "whalesay_jobs_metric" {
  name        = "whalesay-jobs-count"
  description = "Conta os jobs do whalesay"
  filter      = "resource.type=\"build\" AND logName=\"projects/proven-mind-419419/logs/cloudbuild\" AND jsonPayload.message:\"Running: kubectl run whalesay-job\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "job_id"
      value_type  = "STRING"
      description = "O ID do job whalesay"
    }
  }
  label_extractors = {
    "job_id" = "EXTRACT(jsonPayload.message)"
  }
}
resource "google_sql_database_instance" "master" {
  name             = "postgres-master"
  region           = "us-central1"
  database_version = "POSTGRES_13"

  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled = true
    }
    
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }
}

resource "google_sql_database_instance" "replica" {
  name             = "postgres-replica"
  region           = "us-central1"
  database_version = "POSTGRES_13"
  master_instance_name = google_sql_database_instance.master.name

  settings {
    tier = "db-f1-micro"
    
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }

  replica_configuration {
    failover_target = false
  }
}



