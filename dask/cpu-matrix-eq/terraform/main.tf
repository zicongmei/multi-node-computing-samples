resource "google_compute_network" "vpc_network" {
  name                    = "dask-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "dask-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = substr(var.zone, 0, length(var.zone) - 2)
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_dask" {
  name    = "allow-dask"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8786", "8787"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

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

  source_ranges = ["10.0.1.0/24"]
}

resource "google_compute_instance" "dask_node" {
  count        = var.num_vm
  name         = "dask-node-${count.index}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Redirect stdout and stderr to the serial console
    exec > >(tee /dev/ttyS0 | logger -t user-data -s 2>/dev/console) 2>&1
    
    echo "Starting Dask cluster setup..."
    apt-get update
    apt-get install -y python3-pip python3.10-venv
    
    # Create venv and install packages
    cd /home/zicong_google_com
    python3 -m venv venv
    ./venv/bin/pip install "dask[distributed]" numpy scipy
    
    # Start Dask components based on node index
    if [[ $(hostname) == *"dask-node-0"* ]]; then
      echo "Starting dask-scheduler..."
      nohup ./venv/bin/dask scheduler > /var/log/dask-scheduler.log 2>&1 &
      
      echo "Starting dask-worker on scheduler node..."
      nohup ./venv/bin/dask worker localhost:8786 > /var/log/dask-worker.log 2>&1 &
    else
      echo "Starting dask-worker and connecting to dask-node-0..."
      # Retry connecting to the scheduler until it's available
      until nohup ./venv/bin/dask worker dask-node-0:8786 > /var/log/dask-worker.log 2>&1 &
      do
        echo "Scheduler not available yet, retrying in 5 seconds..."
        sleep 5
      done
    fi
    echo "Dask cluster setup script completed."
  EOT

  tags = ["dask"]
}
