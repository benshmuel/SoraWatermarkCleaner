# Deployment Scripts

This directory contains scripts to automate Google Cloud Run deployment.

## Scripts Overview

### `setup-gcloud.sh`
**Purpose**: Initial Google Cloud setup (run once)

**What it does:**
- ✅ Checks for gcloud CLI installation
- ✅ Authenticates your Google account
- ✅ Sets up GCP project
- ✅ Enables required APIs (Cloud Run, Cloud Build, Artifact Registry)
- ✅ Configures Docker authentication
- ✅ Optionally creates service accounts

**Usage:**
```bash
./scripts/setup-gcloud.sh
```

**When to use:**
- First time deployment
- Setting up a new GCP project
- Switching to a different project

---

### `test-deployment.sh`
**Purpose**: Automated deployment testing

**What it does:**
- ✅ Tests health check endpoint
- ✅ Verifies service information
- ✅ Uploads a test video
- ✅ Polls for completion
- ✅ Downloads the result
- ✅ Validates the output

**Usage:**
```bash
./scripts/test-deployment.sh
```

**Requirements:**
- Service must be deployed
- Test video at `resources/dog_vs_sam.mp4`
- `jq` command-line JSON processor (optional)

**When to use:**
- After deployment to verify everything works
- After updates to test changes
- For CI/CD integration

---

## Quick Workflow

### First Time Setup
```bash
# 1. Setup Google Cloud (once)
./scripts/setup-gcloud.sh

# 2. Deploy (from project root)
cd ..
./deploy.sh

# 3. Test
./scripts/test-deployment.sh
```

### Subsequent Updates
```bash
# 1. Deploy changes
./deploy.sh

# 2. Test
./scripts/test-deployment.sh
```

---

## Troubleshooting

### setup-gcloud.sh

**Error: "gcloud command not found"**
```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install
```

**Error: "API not enabled"**
```bash
# APIs are enabled automatically, but if it fails:
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### test-deployment.sh

**Error: "Service URL not found"**
```bash
# Make sure you've deployed first
./deploy.sh

# Or manually set URL
echo "https://your-service-url.run.app" > .service_url
```

**Error: "Test video not found"**
```bash
# Check if test video exists
ls -lh resources/dog_vs_sam.mp4

# If missing, use any .mp4 file
# Update script or copy a video to resources/
```

**Error: "jq: command not found"**
```bash
# Install jq (optional, for pretty JSON output)
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# The script will work without jq, just less pretty output
```

---

## Script Customization

### Changing Default Region

**In setup-gcloud.sh:**
```bash
REGION=${REGION:-us-central1}  # Change default here
```

**Or use environment variable:**
```bash
REGION=europe-west1 ./scripts/setup-gcloud.sh
```

### Adding More Tests

Edit `test-deployment.sh` to add custom tests:

```bash
# Example: Add custom endpoint test
echo ""
echo -e "${YELLOW}Test 7: Custom Endpoint${NC}"
curl -s "$SERVICE_URL/your-endpoint" | jq '.'
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Deployment
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Test
        env:
          SERVICE_URL: ${{ secrets.CLOUD_RUN_URL }}
        run: |
          echo $SERVICE_URL > .service_url
          ./scripts/test-deployment.sh
```

### GitLab CI Example

```yaml
test_deployment:
  script:
    - echo $CLOUD_RUN_URL > .service_url
    - ./scripts/test-deployment.sh
  only:
    - main
```

---

## Environment Variables

### setup-gcloud.sh

| Variable | Default | Description |
|----------|---------|-------------|
| `REGION` | us-central1 | Default GCP region |

### test-deployment.sh

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVICE_URL` | from .service_url | Cloud Run service URL |

---

## Exit Codes

All scripts follow standard exit codes:
- `0` - Success
- `1` - Error/failure

Use in your automation:
```bash
if ./scripts/test-deployment.sh; then
    echo "Deployment verified!"
else
    echo "Deployment test failed!"
    exit 1
fi
```

---

## Additional Resources

- **Main deployment script**: `../deploy.sh`
- **Deployment guide**: `../DEPLOYMENT.md`
- **Quick start**: `../QUICKSTART.md`
- **Google Cloud Run Docs**: https://cloud.google.com/run/docs

