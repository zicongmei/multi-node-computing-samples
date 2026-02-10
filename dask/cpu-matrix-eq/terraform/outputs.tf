output "vm_public_ips" {
  value = google_compute_instance.dask_node[*].network_interface[0].access_config[0].nat_ip
}

output "vm_private_ips" {
  value = google_compute_instance.dask_node[*].network_interface[0].network_ip
}

output "vm_names" {
  value = google_compute_instance.dask_node[*].name
}

output "gcs_output_path" {
  value = var.gcs_output_path
}

output "num_vm" {
  value = var.num_vm
}

output "zone" {
  value = var.zone
}

output "project_id" {
  value = var.project_id
}
