# SoraWatermarkCleaner - Google Cloud Run Deployment Guide

Complete guide for deploying the SoraWatermarkCleaner API to Google Cloud Run and integrating it with your Node.js App Engine application.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deployment Options](#deployment-options)
4. [Node.js Integration](#nodejs-integration)
5. [Configuration](#configuration)
6. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
7. [Security & Authentication](#security--authentication)
8. [Cost Optimization](#cost-optimization)

---

## Prerequisites

### Required Tools

1. **Google Cloud SDK (gcloud)**
   ```bash
   # Install from: https://cloud.google.com/sdk/docs/install
   # Verify installation:
   gcloud --version
   ```

2. **Docker** (optional, for local testing)
   ```bash
   # Install from: https://docs.docker.com/get-docker/
   docker --version
   ```

3. **Node.js** (for App Engine integration)
   ```bash
   node --version
   npm --version
   ```

### Google Cloud Requirements

- Active GCP project with billing enabled
- Required APIs enabled (automated by setup script):
  - Cloud Build API
  - Cloud Run API
  - Artifact Registry API

---

## Initial Setup

### Option 1: Automated Setup (Recommended)

Run the interactive setup script:

```bash
chmod +x scripts/setup-gcloud.sh
./scripts/setup-gcloud.sh
```

This script will:
- ✅ Check for gcloud installation
- ✅ Authenticate your account
- ✅ Set up your GCP project
- ✅ Enable required APIs
- ✅ Configure Docker authentication
- ✅ Create service accounts (optional)

### Option 2: Manual Setup

1. **Authenticate with Google Cloud:**
   ```bash
   gcloud auth login
   ```

2. **Set your project:**
   ```bash
   export PROJECT_ID="your-project-id"
   gcloud config set project $PROJECT_ID
   ```

3. **Enable required APIs:**
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

4. **Set default region:**
   ```bash
   gcloud config set run/region us-central1
   ```

5. **Configure Docker authentication:**
   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

---

## Deployment Options

### Option 1: One-Command Deployment (Easiest)

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Create Artifact Registry repository (if needed)
2. Build Docker image using Cloud Build
3. Deploy to Cloud Run with optimized settings
4. Display your service URL

**Configuration via environment variables:**
```bash
REGION=us-central1 \
MEMORY=4Gi \
CPU=2 \
MAX_INSTANCES=10 \
./deploy.sh
```

### Option 2: Manual Deployment

1. **Create Artifact Registry repository:**
   ```bash
   gcloud artifacts repositories create sora-watermark-cleaner \
       --repository-format=docker \
       --location=us-central1 \
       --description="SoraWatermarkCleaner Docker repository"
   ```

2. **Build and push image:**
   ```bash
   IMAGE_NAME="us-central1-docker.pkg.dev/$PROJECT_ID/sora-watermark-cleaner/app:latest"
   gcloud builds submit --tag $IMAGE_NAME
   ```

3. **Deploy to Cloud Run:**
   ```bash
   gcloud run deploy sora-watermark-cleaner \
       --image $IMAGE_NAME \
       --platform managed \
       --region us-central1 \
       --allow-unauthenticated \
       --memory 4Gi \
       --cpu 2 \
       --timeout 3600 \
       --max-instances 10 \
       --min-instances 0 \
       --port 8080 \
       --set-env-vars "ENVIRONMENT=production"
   ```

4. **Get service URL:**
   ```bash
   gcloud run services describe sora-watermark-cleaner \
       --platform managed \
       --region us-central1 \
       --format 'value(status.url)'
   ```

### Option 3: Local Testing First

```bash
# Build locally
docker build -t sora-watermark-cleaner:local .

# Run locally
docker run -p 8080:8080 sora-watermark-cleaner:local

# Test
curl http://localhost:8080/health

# Deploy after testing
gcloud builds submit --tag $IMAGE_NAME
gcloud run deploy sora-watermark-cleaner --image $IMAGE_NAME ...
```

---

## Node.js Integration

### Setup

1. **Copy the Node.js integration package to your App Engine project:**
   ```bash
   cp -r nodejs-integration /path/to/your/app-engine-project/
   cd /path/to/your/app-engine-project/nodejs-integration
   npm install
   ```

2. **Configure environment:**
   ```bash
   # Create .env file
   echo "SORA_API_URL=https://your-service-url.run.app" > .env
   echo "USE_AUTH=false" >> .env
   ```

### Basic Usage

```javascript
const SoraWatermarkCleanerClient = require('./nodejs-integration/sora-api-client');

const client = new SoraWatermarkCleanerClient(process.env.SORA_API_URL);

// Complete workflow
await client.removeWatermark('input.mp4', 'output.mp4', {
  onProgress: (status) => {
    console.log(`${status.status} - ${status.progress}%`);
  }
});
```

### Express.js Integration

```javascript
const express = require('express');
const multer = require('multer');
const SoraWatermarkCleanerClient = require('./nodejs-integration/sora-api-client');

const app = express();
const upload = multer({ dest: 'uploads/' });
const client = new SoraWatermarkCleanerClient(process.env.SORA_API_URL);

app.post('/api/watermark/remove', upload.single('video'), async (req, res) => {
  const taskId = await client.submitTask(req.file.path);
  res.json({ taskId, statusUrl: `/api/status/${taskId}` });
});

app.get('/api/status/:taskId', async (req, res) => {
  const status = await client.getTaskStatus(req.params.taskId);
  res.json(status);
});

app.get('/api/download/:taskId', async (req, res) => {
  const outputPath = `downloads/${req.params.taskId}.mp4`;
  await client.downloadVideo(req.params.taskId, outputPath);
  res.download(outputPath);
});
```

### App Engine Configuration

**app.yaml:**
```yaml
runtime: nodejs20

instance_class: F2

env_variables:
  SORA_API_URL: "https://your-service-url.run.app"
  USE_AUTH: "true"

automatic_scaling:
  min_instances: 0
  max_instances: 10
```

**Deploy to App Engine:**
```bash
gcloud app deploy
```

---

## Configuration

### Resource Configuration

Adjust resources based on your workload:

```bash
# For small videos (<100MB, <5min)
gcloud run services update sora-watermark-cleaner \
    --memory 2Gi \
    --cpu 1 \
    --timeout 1800

# For medium videos (100-500MB, 5-15min)
gcloud run services update sora-watermark-cleaner \
    --memory 4Gi \
    --cpu 2 \
    --timeout 3600

# For large videos (>500MB, >15min)
gcloud run services update sora-watermark-cleaner \
    --memory 8Gi \
    --cpu 4 \
    --timeout 3600
```

### Environment Variables

Set custom environment variables:

```bash
gcloud run services update sora-watermark-cleaner \
    --update-env-vars "LOG_LEVEL=INFO,MAX_UPLOAD_SIZE=1000000000"
```

### Concurrency Settings

```bash
# Limit concurrent requests (recommended for ML workloads)
gcloud run services update sora-watermark-cleaner \
    --concurrency 1

# Default is 80 - reduce for memory-intensive tasks
```

---

## Monitoring & Troubleshooting

### View Logs

**Real-time logs:**
```bash
gcloud run services logs tail sora-watermark-cleaner --region us-central1
```

**Recent logs:**
```bash
gcloud run services logs read sora-watermark-cleaner \
    --region us-central1 \
    --limit 100
```

**Filter logs:**
```bash
# Errors only
gcloud run services logs read sora-watermark-cleaner \
    --region us-central1 \
    --format "table(timestamp,severity,textPayload)" \
    --filter "severity>=ERROR"
```

### Testing Deployment

Run the test script:

```bash
chmod +x scripts/test-deployment.sh
./scripts/test-deployment.sh
```

Or test manually:

```bash
SERVICE_URL=$(cat .service_url)

# Health check
curl $SERVICE_URL/health

# API docs
open $SERVICE_URL/docs

# Submit test video
curl -X POST "$SERVICE_URL/submit_remove_task" \
    -F "video=@resources/dog_vs_sam.mp4"
```

### Common Issues

**Issue: Container crashes with OOM**
```bash
# Solution: Increase memory
gcloud run services update sora-watermark-cleaner --memory 8Gi
```

**Issue: Timeout errors**
```bash
# Solution: Increase timeout
gcloud run services update sora-watermark-cleaner --timeout 3600
```

**Issue: Cold start delays**
```bash
# Solution: Set min instances
gcloud run services update sora-watermark-cleaner --min-instances 1
```

**Issue: Model download fails**
```bash
# Check logs for network issues
gcloud run services logs read sora-watermark-cleaner | grep -i "download\|error"

# Models are cached after first download
# If persistent, check outbound network access
```

### Metrics & Monitoring

View metrics in Google Cloud Console:
```
https://console.cloud.google.com/run/detail/us-central1/sora-watermark-cleaner/metrics
```

Key metrics to monitor:
- Request count
- Request latency
- Container instance count
- CPU utilization
- Memory utilization

---

## Security & Authentication

### Public Access (Development)

Default deployment allows unauthenticated access:
```bash
gcloud run deploy sora-watermark-cleaner --allow-unauthenticated
```

### Authenticated Access (Production)

1. **Disable public access:**
   ```bash
   gcloud run services update sora-watermark-cleaner \
       --no-allow-unauthenticated
   ```

2. **Create service account for App Engine:**
   ```bash
   SA_NAME="app-engine-caller"
   SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
   
   gcloud iam service-accounts create $SA_NAME \
       --display-name="App Engine API Caller"
   ```

3. **Grant Cloud Run invoker role:**
   ```bash
   gcloud run services add-iam-policy-binding sora-watermark-cleaner \
       --region=us-central1 \
       --member="serviceAccount:$SA_EMAIL" \
       --role="roles/run.invoker"
   ```

4. **Configure App Engine to use service account:**
   
   **app.yaml:**
   ```yaml
   service_account: app-engine-caller@your-project-id.iam.gserviceaccount.com
   ```

5. **Update Node.js client:**
   ```javascript
   const client = new SoraWatermarkCleanerClient(
     process.env.SORA_API_URL,
     { useAuth: true }
   );
   ```

### API Key Authentication (Alternative)

Add custom API key middleware to your FastAPI app:

```python
from fastapi import Header, HTTPException

API_KEY = os.getenv("API_KEY", "your-secret-key")

async def verify_api_key(x_api_key: str = Header(...)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API key")
```

Then deploy with API key:
```bash
gcloud run deploy sora-watermark-cleaner \
    --set-env-vars "API_KEY=your-secret-key"
```

---

## Cost Optimization

### Pricing Overview

Cloud Run pricing factors:
- **CPU time**: Billed per vCPU-second
- **Memory**: Billed per GiB-second
- **Requests**: $0.40 per million requests
- **Network egress**: ~$0.12/GB (varies by region)

### Optimization Strategies

1. **Use CPU throttling when idle:**
   ```bash
   gcloud run deploy sora-watermark-cleaner \
       --cpu-throttling  # CPU only during request processing
   ```

2. **Set appropriate min/max instances:**
   ```bash
   # Dev/test: Scale to zero
   --min-instances 0 --max-instances 5
   
   # Production: Keep warm instance
   --min-instances 1 --max-instances 10
   ```

3. **Choose optimal region:**
   ```bash
   # Cheaper regions: us-central1, us-east1
   # More expensive: asia-northeast1, europe-west1
   ```

4. **Use Cloud Storage for large files:**
   - Store videos in Cloud Storage
   - Process from bucket
   - Reduces network egress costs

5. **Batch processing:**
   - Process multiple videos in one request
   - Reduces request count overhead

### Cost Estimation

Example for 1000 videos/month (5min each, 100MB):

| Resource | Usage | Cost |
|----------|-------|------|
| CPU (2 vCPU) | 2 * 5000 min | ~$24 |
| Memory (4GB) | 4 * 5000 min | ~$5 |
| Requests | 1000 | ~$0 |
| Network | 100GB | ~$12 |
| **Total** | | **~$41/month** |

Use the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) for detailed estimates.

---

## Advanced Topics

### Using Cloud Storage for Videos

1. **Grant Cloud Run access to Cloud Storage:**
   ```bash
   PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
   SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
   
   gsutil iam ch serviceAccount:${SERVICE_ACCOUNT}:roles/storage.objectAdmin gs://your-bucket
   ```

2. **Update code to read from GCS:**
   ```python
   from google.cloud import storage
   
   def download_from_gcs(bucket_name, blob_name, destination):
       client = storage.Client()
       bucket = client.bucket(bucket_name)
       blob = bucket.blob(blob_name)
       blob.download_to_filename(destination)
   ```

### Custom Domains

1. **Map custom domain:**
   ```bash
   gcloud run domain-mappings create \
       --service sora-watermark-cleaner \
       --domain api.yourdomain.com \
       --region us-central1
   ```

2. **Update DNS records** as shown in output

### CI/CD Integration

**GitHub Actions example:**

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Cloud SDK
        uses: google-github-actions/setup-gcloud@v0
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}
      
      - name: Build and Deploy
        run: |
          gcloud builds submit --tag gcr.io/$PROJECT_ID/app
          gcloud run deploy sora-watermark-cleaner \
            --image gcr.io/$PROJECT_ID/app \
            --region us-central1
```

### Multi-Region Deployment

Deploy to multiple regions for global availability:

```bash
REGIONS=("us-central1" "europe-west1" "asia-northeast1")

for REGION in "${REGIONS[@]}"; do
  gcloud run deploy sora-watermark-cleaner \
      --image $IMAGE_NAME \
      --region $REGION \
      --platform managed
done
```

Add a global load balancer to route traffic.

---

## Quick Reference

### Essential Commands

```bash
# Deploy/update
./deploy.sh

# View logs
gcloud run services logs tail sora-watermark-cleaner

# Get service URL
gcloud run services describe sora-watermark-cleaner \
    --format 'value(status.url)'

# Update resources
gcloud run services update sora-watermark-cleaner \
    --memory 4Gi --cpu 2

# Delete service
gcloud run services delete sora-watermark-cleaner

# Test deployment
./scripts/test-deployment.sh
```

### API Endpoints

After deployment, your API will be available at:

- `GET /` - Service information
- `GET /health` - Health check
- `GET /docs` - Interactive API documentation
- `POST /submit_remove_task` - Submit video for processing
- `GET /get_results?remove_task_id=<id>` - Check task status
- `GET /download/<task_id>` - Download processed video

### Support Resources

- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Pricing Calculator**: https://cloud.google.com/products/calculator
- **Cloud Console**: https://console.cloud.google.com/run
- **Status Dashboard**: https://status.cloud.google.com/

---

## Next Steps

1. ✅ Complete initial setup with `./scripts/setup-gcloud.sh`
2. ✅ Deploy with `./deploy.sh`
3. ✅ Test with `./scripts/test-deployment.sh`
4. ✅ Integrate Node.js client into your App Engine app
5. ✅ Enable authentication for production
6. ✅ Set up monitoring and alerts
7. ✅ Optimize costs based on usage patterns

---

**Questions or Issues?**

Check the logs first:
```bash
gcloud run services logs tail sora-watermark-cleaner
```

For detailed debugging, run with verbose output:
```bash
gcloud run deploy sora-watermark-cleaner --verbosity=debug
```

