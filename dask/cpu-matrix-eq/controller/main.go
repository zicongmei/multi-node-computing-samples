package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type TerraformOutputs struct {
	VMPublicIPs struct {
		Value []string `json:"value"`
	} `json:"vm_public_ips"`
	VMPrivateIPs struct {
		Value []string `json:"value"`
	} `json:"vm_private_ips"`
	VMNames struct {
		Value []string `json:"value"`
	} `json:"vm_names"`
	GCSOutputPath struct {
		Value string `json:"value"`
	} `json:"gcs_output_path"`
	NumVM struct {
		Value int `json:"value"`
	} `json:"num_vm"`
	Zone struct {
		Value string `json:"value"`
	} `json:"zone"`
	ProjectID struct {
		Value string `json:"value"`
	} `json:"project_id"`
}

func main() {
	destroy := flag.Bool("destroy", false, "Destroy the infrastructure after completion")
	flag.Parse()

	repoRoot, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		log.Fatalf("Failed to find repo root: %v", err)
	}
	root := strings.TrimSpace(string(repoRoot))

	tfDir := filepath.Join(root, "dask/cpu-matrix-eq/terraform")
	scriptsDir := filepath.Join(root, "dask/cpu-matrix-eq/scripts")

	// 1. Provision VMs with Terraform
	fmt.Println("Step 1: Provisioning VMs with Terraform...")
	if err := runCmd(tfDir, "terraform", "apply", "-auto-approve"); err != nil {
		log.Fatalf("Terraform apply failed: %v", err)
	}

	// Get Terraform outputs
	outputData, err := exec.Command("terraform", "-chdir="+tfDir, "output", "-json").Output()
	if err != nil {
		log.Fatalf("Failed to get terraform output: %v", err)
	}

	var outputs TerraformOutputs
	if err := json.Unmarshal(outputData, &outputs); err != nil {
		log.Fatalf("Failed to unmarshal terraform output: %v", err)
	}

	if len(outputs.VMNames.Value) == 0 {
		log.Fatal("No VM names found in terraform output")
	}

	headNode := outputs.VMNames.Value[0]
	numVMs := outputs.NumVM.Value
	zone := outputs.Zone.Value
	project := outputs.ProjectID.Value

	fmt.Printf("Head node: %s\n", headNode)
	fmt.Printf("Number of VMs: %d\n", numVMs)
	fmt.Printf("Zone: %s\n", zone)
	fmt.Printf("Project: %s\n", project)

	// 2. Wait for all VMs to be registered in Dask
	fmt.Println("Step 2: Waiting for all VMs to be registered in Dask...")
	waitForDaskWorkers(headNode, project, zone, numVMs)

	// 3. SSH into node 0 to run the solver
	fmt.Println("Step 3: Running solver on head node...")
	
	// First, scp the solver script
	solverPath := filepath.Join(scriptsDir, "solver.py")
	scpCmd := []string{"compute", "scp", solverPath, fmt.Sprintf("%s:/tmp/solver.py", headNode), "--project", project, "--zone", zone, "--quiet"}
	fmt.Printf("Uploading solver script via: gcloud %s\n", strings.Join(scpCmd, " "))
	if err := runCmd(".", "gcloud", scpCmd...); err != nil {
		log.Fatalf("Failed to scp solver script: %v", err)
	}

	// Run the solver
	solverCmd := "/opt/dask-venv/bin/python3 -u /tmp/solver.py --scheduler localhost:8786 --size 5000"
	sshCmd := []string{"compute", "ssh", headNode, "--project", project, "--zone", zone, "--command", solverCmd, "--quiet"}
	
	fmt.Printf("Executing solver command via: gcloud %s\n", strings.Join(sshCmd, " "))
	cmd := exec.Command("gcloud", sshCmd...)
	var solverOutput bytes.Buffer
	cmd.Stdout = io.MultiWriter(os.Stdout, &solverOutput)
	cmd.Stderr = io.MultiWriter(os.Stderr, &solverOutput)

	if err := cmd.Run(); err != nil {
		log.Fatalf("Solver execution failed: %v", err)
	}
	
	resultFile := "solver_output.txt"
	if err := os.WriteFile(resultFile, solverOutput.Bytes(), 0644); err != nil {
		log.Fatalf("Failed to write result to file: %v", err)
	}
	fmt.Println("Solver output saved locally to", resultFile)

	// 4. Save the result to GCS
	fmt.Println("Step 4: Saving result to GCS...")
	fullGCSPath := fmt.Sprintf("%s/solver_output.txt", outputs.GCSOutputPath.Value)
	if err := runCmd(".", "gcloud", "storage", "cp", resultFile, fullGCSPath); err != nil {
		log.Fatalf("Failed to upload result to GCS: %v", err)
	}
	fmt.Printf("Result uploaded to %s\n", fullGCSPath)

	// 5. Optional destroy
	if *destroy {
		fmt.Println("Step 5: Destroying infrastructure...")
		if err := runCmd(tfDir, "terraform", "destroy", "-auto-approve"); err != nil {
			log.Fatalf("Terraform destroy failed: %v", err)
		}
	} else {
		fmt.Println("Skipping infrastructure destruction.")
	}
}

func runCmd(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func waitForDaskWorkers(headNode, project, zone string, expectedWorkers int) {
	checkCmd := "/opt/dask-venv/bin/python3 -c \"from dask.distributed import Client; client = Client('localhost:8786'); print(len(client.scheduler_info()['workers']))\""
	
	maxRetries := 60 // 10 minutes
	for i := 0; i < maxRetries; i++ {
		sshCmd := []string{"compute", "ssh", headNode, "--project", project, "--zone", zone, "--command", checkCmd}
		output, err := exec.Command("gcloud", sshCmd...).Output()
		if err == nil {
			numWorkers := strings.TrimSpace(string(output))
			fmt.Printf("Current workers: %s/%d\n", numWorkers, expectedWorkers)
			if numWorkers == fmt.Sprintf("%d", expectedWorkers) {
				fmt.Println("All workers registered!")
				return
			}
		} else {
			fmt.Printf("Waiting for scheduler to be ready (attempt %d/%d)...\n", i+1, maxRetries)
		}
		time.Sleep(10 * time.Second)
	}
	log.Fatalf("Timeout waiting for workers to register")
}
