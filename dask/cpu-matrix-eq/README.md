# Dask CPU Matrix Equation Solver

This example demonstrates how to solve a large matrix equation ($Ax = b$) using Dask distributed across multiple VMs on Google Cloud Platform (GCP).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed.
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated.
- A GCP Project ID.

## Deployment

### 1. Provision Infrastructure

Navigate to the `terraform` directory and initialize:

```bash
cd terraform
terraform init
```

Apply the configuration (replace `<PROJECT_ID>` with your project ID):

```bash
terraform apply -var="project_id=<PROJECT_ID>" -var="zone=us-central1-a" -var="num_vm=3"
```

Terraform will output the public and private IPs of the created VMs.

### 2. Accessing the VMs

You can SSH into the VMs using the `gcloud` command:

```bash
gcloud compute ssh dask-node-0 --zone=us-central1-a
```

### 3. Set Up Dask Cluster

The cluster is automatically set up via the `metadata_startup_script` in the Terraform configuration:
- **dask-node-0**: Starts the `dask-scheduler`.
- **Other nodes**: Start a `dask-worker` connected to `dask-node-0`.

You can check the logs on each VM at `/var/log/dask-scheduler.log` or `/var/log/dask-worker.log`.

### 4. Copy Scripts to the Cluster

Copy the `scripts` directory to `dask-node-0`:

```bash
gcloud compute scp --recurse scripts dask-node-0:~/ --zone=us-central1-a
```

### 5. Run the Solver

#### Option A: Running from the Scheduler Node (dask-node-0)

SSH into `dask-node-0`:

```bash
gcloud compute ssh dask-node-0 --zone=us-central1-a
```

Then run the solver (the scheduler is running locally on this node):

```bash
python3 scripts/solver.py --scheduler localhost:8786 --size 10000
```

#### Option B: Running from your local Workstation

You can also run the solver directly from your workstation if you have Dask installed. You will need to use the **Public IP** of `dask-node-0` (found in the Terraform output).

```bash
python3 dask/cpu-matrix-eq/scripts/solver.py --scheduler <SCHEDULER_PUBLIC_IP>:8786 --size 10000
```

## Monitoring

The Dask dashboard is available at `http://<SCHEDULER_PUBLIC_IP>:8787`. You can use this to monitor task progress and resource usage.

## Cleanup

To avoid ongoing charges, destroy the infrastructure when finished:

```bash
terraform destroy -var="project_id=<PROJECT_ID>"
```
