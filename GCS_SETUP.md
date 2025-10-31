# Google Cloud Storage (GCS) Setup Guide

This guide explains how to configure and use Google Cloud Storage as the storage backend for SoraWatermarkCleaner, replacing the local filesystem storage.

## Why Use Google Cloud Storage?

When deploying to Cloud Run or other cloud platforms, using GCS provides several advantages:

- **Persistent Storage**: Files persist across container restarts and scale-downs
- **Scalability**: No disk space limitations
- **Multi-Instance Access**: Multiple Cloud Run instances can access the same files
- **Durability**: 99.999999999% (11 9's) durability for your data
- **Cost-Effective**: Pay only for what you use, with no upfront costs

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Google Cloud SDK (gcloud)** installed and authenticated
3. **google-cloud-storage** Python package (already added to dependencies)

## Step 1: Create a GCS Bucket

### Option A: Using gcloud CLI

```bash
# Set your project ID
PROJECT_ID="your-project-id"
BUCKET_NAME="sora-watermark-cleaner-storage"
REGION="us-central1"

# Create the bucket
gcloud storage buckets create gs://${BUCKET_NAME} \
    --project=${PROJECT_ID} \
    --location=${REGION} \
    --uniform-bucket-level-access

# Set lifecycle policy to auto-delete old files (optional)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "matchesPrefix": ["uploads/", "outputs/"]
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://${BUCKET_NAME}
```

### Option B: Using Google Cloud Console

1. Go to [Cloud Storage Browser](https://console.cloud.google.com/storage/browser)
2. Click **Create Bucket**
3. Enter bucket name: `sora-watermark-cleaner-storage`
4. Choose location: `us-central1` (or your preferred region)
5. Choose storage class: **Standard**
6. Choose access control: **Uniform**
7. Click **Create**

## Step 2: Configure IAM Permissions

### For Cloud Run Deployment

Grant your Cloud Run service account access to the bucket:

```bash
PROJECT_ID="your-project-id"
BUCKET_NAME="sora-watermark-cleaner-storage"

# Get the Cloud Run service account
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Grant storage admin access
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectAdmin"

# Verify permissions
gcloud storage buckets get-iam-policy gs://${BUCKET_NAME}
```

### For Local Development

```bash
# Authenticate with your user account
gcloud auth application-default login

# Or use a service account key (not recommended for production)
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

## Step 3: Configure Environment Variables

### For Cloud Run

Update your `deploy.sh` or deployment command to include GCS environment variables:

```bash
gcloud run deploy sora-watermark-cleaner \
    --image gcr.io/${PROJECT_ID}/sora-watermark-cleaner \
    --platform managed \
    --region us-central1 \
    --memory 8Gi \
    --timeout 3600 \
    --set-env-vars "USE_GCS=true" \
    --set-env-vars "GCS_BUCKET_NAME=sora-watermark-cleaner-storage" \
    --set-env-vars "GCS_PROJECT_ID=${PROJECT_ID}" \
    --set-env-vars "GCS_UPLOADS_PREFIX=uploads" \
    --set-env-vars "GCS_OUTPUTS_PREFIX=outputs"
```

### For Local Development

Create a `.env` file in your project root:

```bash
# Enable GCS storage
USE_GCS=true

# GCS Configuration
GCS_BUCKET_NAME=sora-watermark-cleaner-storage
GCS_PROJECT_ID=your-project-id

# Optional: Customize storage paths
GCS_UPLOADS_PREFIX=uploads
GCS_OUTPUTS_PREFIX=outputs
```

Then load it before running:

```bash
# Using python-dotenv
pip install python-dotenv

# Or manually export
export $(cat .env | xargs)
python start_server.py
```

## Step 4: Update Dockerfile (if needed)

The existing Dockerfile should work, but ensure the service account authentication works:

```dockerfile
# The Cloud Run environment automatically provides credentials
# No changes needed for Cloud Run deployment

# For local development, mount credentials:
# docker run -v ~/.config/gcloud:/root/.config/gcloud ...
```

## Step 5: Test the Setup

### Test GCS Connection

Create a test script `test_gcs.py`:

```python
import os
from sorawm.iopaint.file_manager.storage_backends import GCSStorageBackend

# Configure
bucket_name = os.getenv("GCS_BUCKET_NAME", "sora-watermark-cleaner-storage")

# Test connection
try:
    backend = GCSStorageBackend(bucket_name=bucket_name)
    
    # Test write
    test_data = b"Hello, GCS!"
    backend.save("test/hello.txt", test_data)
    print("✓ Write successful")
    
    # Test read
    data = backend.read("test/hello.txt")
    assert data == test_data
    print("✓ Read successful")
    
    # Test exists
    exists = backend.exists("test/hello.txt")
    assert exists
    print("✓ Exists check successful")
    
    # Test signed URL
    url = backend.get_signed_url("test/hello.txt")
    print(f"✓ Signed URL generated: {url[:50]}...")
    
    # Cleanup
    backend.delete("test/hello.txt")
    print("✓ Delete successful")
    
    print("\n✅ All GCS tests passed!")
    
except Exception as e:
    print(f"❌ GCS test failed: {e}")
```

Run the test:

```bash
export USE_GCS=true
export GCS_BUCKET_NAME=sora-watermark-cleaner-storage
python test_gcs.py
```

### Test Full Workflow

```bash
# Start the server with GCS enabled
export USE_GCS=true
export GCS_BUCKET_NAME=sora-watermark-cleaner-storage
python start_server.py

# In another terminal, submit a test task
curl -X POST "http://localhost:8080/submit_remove_task" \
  -F "video=@resources/puppies.mp4"

# Check results (replace TASK_ID with the returned task_id)
curl "http://localhost:8080/get_results?remove_task_id=TASK_ID"

# Download result (will redirect to GCS signed URL)
curl -L "http://localhost:8080/download/TASK_ID" -o output.mp4
```

## Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `USE_GCS` | No | `false` | Enable GCS storage backend |
| `GCS_BUCKET_NAME` | Yes* | `None` | Name of the GCS bucket |
| `GCS_PROJECT_ID` | No | Auto-detected | Google Cloud project ID |
| `GCS_UPLOADS_PREFIX` | No | `uploads` | Path prefix for uploaded videos |
| `GCS_OUTPUTS_PREFIX` | No | `outputs` | Path prefix for processed videos |

*Required when `USE_GCS=true`

### Bucket Structure

When using GCS, files are organized as:

```
gs://your-bucket/
├── uploads/
│   ├── {task_id}_{filename}.mp4
│   └── ...
└── outputs/
    ├── {task_id}_{timestamp}.mp4
    └── ...
```

## How It Works

### Storage Flow

1. **Video Upload**: Client uploads video → API saves to `uploads/` in GCS
2. **Processing**: Worker downloads from GCS → processes locally → uploads result to `outputs/`
3. **Download**: Client requests download → API generates signed URL → redirects to GCS

### Signed URLs

For security and performance, the API generates signed URLs (valid for 1 hour) that allow direct download from GCS without routing through your API server.

### Local Temp Files

During processing, videos are temporarily downloaded to local storage for processing, then uploaded back to GCS. This ensures:
- Fast processing (local disk I/O)
- Persistent results (GCS storage)
- Clean temporary files (auto-cleanup after processing)

## Cost Optimization

### Storage Costs

- **Standard Storage**: $0.020 per GB/month
- **Operations**: $0.05 per 10,000 operations

Example: Processing 100 videos/day (1GB each):
- Storage: ~$6/month (assuming 30-day retention)
- Operations: ~$1/month

### Reduce Costs

1. **Set Lifecycle Policies** to auto-delete old files:

```bash
gsutil lifecycle set lifecycle.json gs://${BUCKET_NAME}
```

2. **Use Regional Storage** (cheaper than multi-regional)

3. **Monitor Usage**:

```bash
# Check bucket size
gsutil du -sh gs://${BUCKET_NAME}

# List largest files
gsutil du gs://${BUCKET_NAME}/** | sort -n -r | head -10
```

## Troubleshooting

### Error: "Could not automatically determine credentials"

**Solution**: Authenticate with gcloud:

```bash
gcloud auth application-default login
```

### Error: "403 Forbidden" or "Permission Denied"

**Solution**: Check IAM permissions:

```bash
gcloud storage buckets get-iam-policy gs://${BUCKET_NAME}
```

Grant access:

```bash
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
    --member="user:your-email@example.com" \
    --role="roles/storage.objectAdmin"
```

### Error: "Bucket not found"

**Solution**: Verify bucket name and project:

```bash
gcloud storage buckets list --project=${PROJECT_ID}
```

### Slow Download Speeds

**Cause**: Files are being downloaded through your API server instead of directly from GCS.

**Solution**: Ensure `USE_GCS=true` is set so signed URLs are used for downloads.

### High Costs

**Solution**: 
1. Set up lifecycle policies to delete old files
2. Check for duplicate uploads
3. Monitor with Cloud Console

```bash
# View cost breakdown
gcloud billing accounts list
gcloud billing projects describe ${PROJECT_ID}
```

## Switching Between Local and GCS

You can switch between storage backends by changing the `USE_GCS` environment variable:

```bash
# Use local storage
export USE_GCS=false
python start_server.py

# Use GCS storage
export USE_GCS=true
export GCS_BUCKET_NAME=your-bucket-name
python start_server.py
```

No code changes required! The application automatically uses the appropriate backend.

## Security Best Practices

1. **Use Uniform Bucket-Level Access**: Prevents ACL complexity
2. **Enable Signed URLs**: Don't make bucket publicly accessible
3. **Set CORS Policies** if needed:

```bash
gsutil cors set cors.json gs://${BUCKET_NAME}
```

Example `cors.json`:

```json
[
  {
    "origin": ["https://your-domain.com"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

4. **Use Service Accounts**: Grant minimal required permissions
5. **Enable Audit Logging**: Monitor access to sensitive data

```bash
gcloud logging read "resource.type=gcs_bucket AND resource.labels.bucket_name=${BUCKET_NAME}"
```

## Monitoring and Logging

### View GCS Access Logs

```bash
# Recent bucket access
gcloud logging read "resource.type=gcs_bucket" --limit 50

# Filter by bucket
gcloud logging read "resource.type=gcs_bucket AND resource.labels.bucket_name=${BUCKET_NAME}" --limit 20
```

### Monitor Storage Usage

```bash
# Bucket metrics in Cloud Console
echo "https://console.cloud.google.com/storage/browser/${BUCKET_NAME}"

# CLI monitoring
watch -n 60 "gsutil du -sh gs://${BUCKET_NAME}"
```

## Migration from Local Storage

If you have existing data in local storage, migrate it to GCS:

```bash
# Sync local directory to GCS
gsutil -m rsync -r ./working_dir/uploads gs://${BUCKET_NAME}/uploads
gsutil -m rsync -r ./working_dir/outputs gs://${BUCKET_NAME}/outputs

# Verify
gsutil ls -r gs://${BUCKET_NAME}
```

## Next Steps

- [ ] Set up lifecycle policies for automatic cleanup
- [ ] Configure monitoring alerts for bucket usage
- [ ] Set up automated backups (if needed)
- [ ] Review and optimize costs monthly
- [ ] Test disaster recovery procedures

## Additional Resources

- [Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [Cloud Storage Pricing](https://cloud.google.com/storage/pricing)
- [Best Practices](https://cloud.google.com/storage/docs/best-practices)
- [Python Client Library](https://cloud.google.com/python/docs/reference/storage/latest)

