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

### 2. Set Up Dask Cluster

Identify one VM to be the **Scheduler** and the others to be **Workers**.

#### On the Scheduler VM:
SSH into the first VM and start the scheduler:
```bash
dask-scheduler
```

#### On the Worker VMs:
SSH into each worker VM and start the worker, pointing it to the scheduler's **private IP**:
```bash
dask-worker <SCHEDULER_PRIVATE_IP>:8786
```

### 3. Run the Solver

You can run the solver from your local machine (if you have Dask installed and can reach the public IP) or from one of the VMs.

```bash
python3 solver.py --scheduler <SCHEDULER_PUBLIC_IP_OR_PRIVATE_IP>:8786 --size 10000
```

## Monitoring

The Dask dashboard is available at `http://<SCHEDULER_PUBLIC_IP>:8787`. You can use this to monitor task progress and resource usage.

## Cleanup

To avoid ongoing charges, destroy the infrastructure when finished:

```bash
terraform destroy -var="project_id=<PROJECT_ID>"
```
