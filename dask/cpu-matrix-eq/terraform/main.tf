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
    mkdir -p /opt/dask-venv
    python3 -m venv /opt/dask-venv
    /opt/dask-venv/bin/pip install "dask[distributed]" numpy scipy
    
    # Start Dask components based on node index
    if [[ $(hostname) == *"dask-node-0"* ]]; then
      echo "Starting dask-scheduler..."
      nohup /opt/dask-venv/bin/dask scheduler > /var/log/dask-scheduler.log 2>&1 &
      
      echo "Waiting for scheduler to start locally..."
      for i in {1..30}; do
        if /opt/dask-venv/bin/python3 -c "import socket; s = socket.socket(); s.connect(('localhost', 8786))" > /dev/null 2>&1; then
          echo "Scheduler is up!"
          break
        fi
        echo "Waiting for scheduler... ($i/30)"
        sleep 2
      done

      echo "Starting dask-worker on scheduler node..."
      nohup /opt/dask-venv/bin/dask worker localhost:8786 > /var/log/dask-worker.log 2>&1 &
    else
      echo "Waiting for dask-node-0:8786 to be available..."
      for i in {1..60}; do
        if /opt/dask-venv/bin/python3 -c "import socket; s = socket.socket(); s.connect(('dask-node-0', 8786))" > /dev/null 2>&1; then
          echo "Scheduler is available at dask-node-0!"
          break
        fi
        echo "Waiting for dask-node-0:8786... ($i/60)"
        sleep 5
      done

      echo "Starting dask-worker and connecting to dask-node-0..."
      nohup /opt/dask-venv/bin/dask worker dask-node-0:8786 > /var/log/dask-worker.log 2>&1 &
    fi
    echo "Dask cluster setup script completed."
  EOT

  tags = ["dask"]
}
