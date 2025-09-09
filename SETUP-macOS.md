# Local Setup — macOS (Docker Desktop + k3d + kubectl + helm)

This guide captures the exact steps we used to fix the `Please install k3d` error and get the local cluster running.

> Target: simple, reliable, **no heavy tooling**. Works on an M1/M2/M3 Mac with Docker Desktop.

---

## 1) Install & start Docker Desktop
- Download and install **Docker Desktop for Mac**.
- Open Docker Desktop and wait until it shows **Running**.
- Quick sanity check in Terminal:
```bash
docker ps
```

If you see containers (or even an empty list without an error), Docker is running.

---

## 2) Install CLI prerequisites with Homebrew
If you don't have Homebrew:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Install the tools:
```bash
brew install k3d kubectl helm
```

Verify:
```bash
k3d version
kubectl version --client
helm version
```

---

## 3) Run Step 1 of the project (create cluster + local registry)
From the project root (where the `scripts` folder is):
```bash
chmod +x scripts/*.sh   # first time only
./scripts/setup.sh
```

What this does:
- Creates a **k3d** cluster named `acl`.
- Creates a **local Docker registry** at `localhost:5001`.
- Prints your nodes as a quick check.

Optional check:
```bash
kubectl get nodes
```

---

## 4) Next steps (for reference)
After the cluster is up, continue with the project’s main README:
```bash
# Build & push the API image to local registry
./scripts/build_and_push.sh

# Deploy Postgres + API (Helm)
./scripts/deploy.sh

# Port-forward the API (in a separate terminal)
kubectl port-forward svc/api-service 3000:3000
```

Then test:
```bash
curl -s http://localhost:3000/healthz
curl -s http://localhost:3000/users | jq
curl -s http://localhost:3000/orders | jq
```

---

## Troubleshooting
- **Cannot connect to the Docker daemon**  
  Open Docker Desktop → wait until it says **Running** → retry the command.

- **Command not found: k3d/kubectl/helm**  
  Make sure Homebrew is installed and your shell is using it (see step 2); re-run the `brew install` line.

- **Still stuck?**  
  Capture your terminal output and we’ll add a fix here.

---

## ✅ Verified on your machine

The following sequence worked end‑to‑end on macOS:

**A) Start/verify Docker Desktop**
```bash
# Open Docker Desktop and wait for Running
docker ps
docker info | head -20
# If needed:
echo $DOCKER_HOST
unset DOCKER_HOST
docker ps
```

**B) Keep repo consistent after switching registry port to 5002**
```bash
sed -i '' 's/REG_PORT="5001"/REG_PORT="5002"/' scripts/setup.sh
sed -i '' 's/localhost:5001/localhost:5002/g' scripts/build_and_push.sh helm/api/values.yaml
grep -R "5002" -n scripts helm/api/values.yaml
```

**C) Create cluster again**
```bash
chmod +x scripts/*.sh     # first time only
./scripts/setup.sh
kubectl get nodes
```

_Result: cluster + local registry up successfully._

---

## ✅ Step 2 — Build & Push API Image

From the project root, run:
```bash
./scripts/build_and_push.sh
```

This will:
- Build the **acl-api** Docker image using `api/Dockerfile`.
- Tag the image with your current git commit SHA and `latest`.
- Push it to the local registry (`localhost:5001` or `localhost:5002` if you changed ports).

### Verification (optional)
```bash
docker images | grep acl-api
# For port 5002:
curl -s http://localhost:5002/v2/_catalog | jq
# For port 5001:
curl -s http://localhost:5001/v2/_catalog | jq
```

If you see `"acl-api"` in the catalog, the push worked.

### Notes
- On Apple Silicon (M1/M2/M3), if you ever hit a build issue, prefix with:
  ```bash
  DOCKER_DEFAULT_PLATFORM=linux/amd64 ./scripts/build_and_push.sh
  ```

_Result: API image available in local registry and ready for deployment._

---

## ✅ Step 3 (Workaround) — API Image Import & Deployment Fix

On macOS with k3d, the API initially failed with `ImagePullBackOff` because pods could not reach the host registry (`localhost:5002`).  
The following sequence worked to resolve it:

**1) Retag and import image into k3d nodes**
```bash
# Retag host image to cluster-friendly name
docker tag localhost:5002/acl-api:latest acl-api:latest

# Import the image into the k3d cluster
k3d image import acl-api:latest -c acl
```

**2) Redeploy API using node-local image**
```bash
helm upgrade --install api ./helm/api   -f helm/api/values.yaml   --set image.repository=acl-api   --set image.tag=latest   --set-file mappingYaml=./config/mappings.yml
```

**3) Restart Deployment to pick up image**
```bash
kubectl rollout restart deploy/api-deployment
```

**4) Verify pods**
```bash
kubectl get pods -w
```
Expected: API pod transitions to `Running (1/1)`, Postgres stays `Running`.

_Result: API successfully deployed and running after image import workaround._

---

## ✅ Step 4 — Port-Forward & Smoke Test

With Postgres and API pods running, verify functionality end-to-end.

**1) Port-forward the API service (keep running in one terminal):**
```bash
kubectl port-forward svc/api-service 3000:3000
```

**2) Test endpoints from another terminal:**
```bash
# Health check
curl -s http://localhost:3000/healthz

# Users
curl -s http://localhost:3000/users | jq

# Orders
curl -s http://localhost:3000/orders | jq
```

**3) Expected outputs:**
- `/healthz` → `{"status":"ok"}`
- `/users` → JSON array of seeded users (Ada Lovelace, Alan Turing)
- `/orders` → JSON array of seeded orders joined with user names

_Result: API confirmed working locally via port-forward._

---

## ℹ️ Note on Step 5 (GitOps loop)

The project includes a local GitOps demo script (`scripts/gitops.sh`) which can
auto-apply config/code changes when you commit to branch `main`.  

**However, this step is *optional* and not required** to run or review the core
project. Steps 1–4 are sufficient to get a working deployment with Postgres and
the API.  

You can skip Step 5 entirely if you only want to validate the deployment and
API endpoints.
