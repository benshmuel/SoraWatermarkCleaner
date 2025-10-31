# Google Cloud Storage - Quick Start

A 5-minute guide to enable Google Cloud Storage for your SoraWatermarkCleaner deployment.

## Prerequisites

- Google Cloud project with billing enabled
- `gcloud` CLI installed and authenticated

## Setup Steps

### 1. Create GCS Bucket (2 minutes)

```bash
# Set variables
PROJECT_ID="your-project-id"
BUCKET_NAME="sora-watermark-storage"
REGION="us-central1"

# Create bucket
gcloud storage buckets create gs://${BUCKET_NAME} \
    --project=${PROJECT_ID} \
    --location=${REGION} \
    --uniform-bucket-level-access
```

### 2. Grant Permissions (1 minute)

```bash
# Get Cloud Run service account
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Grant access to bucket
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectAdmin"
```

### 3. Deploy with GCS (2 minutes)

```bash
# Set environment variables
export USE_GCS=true
export GCS_BUCKET_NAME="${BUCKET_NAME}"

# Deploy
./deploy.sh
```

## That's it! 🎉

Your SoraWatermarkCleaner is now using Google Cloud Storage.

### Test It

```bash
# Get your service URL
SERVICE_URL=$(cat .service_url)

# Submit a test video
curl -X POST "${SERVICE_URL}/submit_remove_task" \
  -F "video=@resources/puppies.mp4"

# The video will be stored in GCS at:
# gs://your-bucket/uploads/
# gs://your-bucket/outputs/
```

## Local Development

For testing locally with GCS:

```bash
# Authenticate
gcloud auth application-default login

# Set environment
export USE_GCS=true
export GCS_BUCKET_NAME="sora-watermark-storage"

# Run server
python start_server.py
```

## Environment Variables

| Variable | Value | Required |
|----------|-------|----------|
| `USE_GCS` | `true` | Yes |
| `GCS_BUCKET_NAME` | Your bucket name | Yes |
| `GCS_PROJECT_ID` | Auto-detected | No |
| `GCS_UPLOADS_PREFIX` | `uploads` (default) | No |
| `GCS_OUTPUTS_PREFIX` | `outputs` (default) | No |

## Troubleshooting

**Permission Denied?**
```bash
# Re-grant permissions
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectAdmin"
```

**Bucket Not Found?**
```bash
# List your buckets
gcloud storage buckets list --project=${PROJECT_ID}
```

**Need More Help?**

See the full [GCS Setup Guide](GCS_SETUP.md) for detailed information.

