# Dask Matrix Equation Controller

This Go-based controller automates the lifecycle of a Dask cluster for solving matrix equations.

## Features

1.  **Provisioning**: Automatically provisions Google Cloud VMs using Terraform.
2.  **Registration Check**: Waits for all Dask workers to register with the scheduler.
3.  **Solver Execution**: SSHs into the head node to run the `solver.py` script.
4.  **Result Persistence**: Saves the solver output to Google Cloud Storage (GCS).
5.  **Cleanup**: Optionally destroys the infrastructure after completion.

## Prerequisites

-   Go 1.18+
-   Terraform
-   Google Cloud SDK (`gcloud`)
-   SSH access to GCE instances configured

## Usage

1.  Navigate to the controller directory:
    ```bash
    cd dask/cpu-matrix-eq/controller
    ```

2.  Run the controller:
    ```bash
    go run main.go [flags]
    ```

### Flags

-   `-destroy`: If set to `true`, destroys the Terraform-managed infrastructure after the solver finishes.

### Example

To run the solver and then destroy the infrastructure:
```bash
go run main.go -destroy
```

## Configuration

The following variables should be configured in `terraform/terraform.tfvars`:

-   `project_id`: Your Google Cloud Project ID.
-   `num_vm`: The number of VMs to provision (e.g., 4).
-   `gcs_output_path`: The GCS path to save the results (e.g., `gs://zicong-test-2/dask`).

The controller automatically reads these values from Terraform outputs.
