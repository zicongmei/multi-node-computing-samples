output "vm_public_ips" {
  value = google_compute_instance.dask_node[*].network_interface[0].access_config[0].nat_ip
}

output "vm_private_ips" {
  value = google_compute_instance.dask_node[*].network_interface[0].network_ip
}

output "vm_names" {
  value = google_compute_instance.dask_node[*].name
}
