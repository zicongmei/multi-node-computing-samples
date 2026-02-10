terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = substr(var.zone, 0, length(var.zone) - 2)
  zone    = var.zone
}
