variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "zone" {
  description = "The zone to provision resources in"
  type        = string
  default     = "us-central1-a"
}

variable "num_vm" {
  description = "The number of VMs to provision"
  type        = number
  default     = 4
}

variable "machine_type" {
  description = "The machine type for the VMs"
  type        = string
  default     = "e2-medium"
}
