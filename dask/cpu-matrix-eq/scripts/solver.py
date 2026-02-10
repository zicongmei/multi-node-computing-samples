import dask.array as da
from dask.distributed import Client
import argparse
import time

def solve_matrix_equation(scheduler_address, size=10000):
    print(f"Connecting to scheduler at {scheduler_address}...")
    client = Client(scheduler_address)
    print("Connected!")

    # Generate large random matrix A and vector b
    print(f"Generating random {size}x{size} matrix A and vector b...")
    A = da.random.random((size, size), chunks=(size // 4, size // 4))
    b = da.random.random((size, 1), chunks=(size // 4, 1))

    # Solve Ax = b
    # Note: For very large matrices, we use da.linalg.solve
    print("Solving Ax = b...")
    start_time = time.time()
    x = da.linalg.solve(A, b)
    
    # Trigger computation
    result = x.compute()
    end_time = time.time()

    print(f"Solve completed in {end_time - start_time:.2f} seconds.")
    print(f"Result shape: {result.shape}")
    
    # Verify: Check if ||Ax - b|| is small
    print("Verifying result...")
    error = da.linalg.norm(A @ x - b).compute()
    print(f"Residual norm: {error}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Dask Matrix Equation Solver")
    parser.add_argument("--scheduler", type=str, required=True, help="Address of the Dask scheduler (e.g., 10.0.1.2:8786)")
    parser.add_argument("--size", type=int, default=10000, help="Size of the square matrix (size x size)")
    
    args = parser.parse_args()
    solve_matrix_equation(args.scheduler, args.size)
