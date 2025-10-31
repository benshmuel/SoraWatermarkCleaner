#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SoraWatermarkCleaner Cloud Run Deployment ===${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: No GCP project set${NC}"
    echo "Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${GREEN}Project ID:${NC} $PROJECT_ID"

# Configuration
REGION=${REGION:-us-central1}
SERVICE_NAME=${SERVICE_NAME:-sora-watermark-cleaner}
REPO_NAME=${REPO_NAME:-sora-watermark-cleaner}
MEMORY=${MEMORY:-4Gi}
CPU=${CPU:-2}
TIMEOUT=${TIMEOUT:-3600}
MAX_INSTANCES=${MAX_INSTANCES:-10}
MIN_INSTANCES=${MIN_INSTANCES:-0}

# GCS Storage Configuration (optional)
USE_GCS=${USE_GCS:-false}
GCS_BUCKET_NAME=${GCS_BUCKET_NAME:-}
GCS_UPLOADS_PREFIX=${GCS_UPLOADS_PREFIX:-uploads}
GCS_OUTPUTS_PREFIX=${GCS_OUTPUTS_PREFIX:-outputs}

echo -e "${YELLOW}Configuration:${NC}"
echo "  Region: $REGION"
echo "  Service Name: $SERVICE_NAME"
echo "  Memory: $MEMORY"
echo "  CPU: $CPU"
echo "  Timeout: ${TIMEOUT}s"
echo "  Max Instances: $MAX_INSTANCES"
echo "  Min Instances: $MIN_INSTANCES"
echo ""
echo -e "${YELLOW}Storage Configuration:${NC}"
echo "  Use GCS: $USE_GCS"
if [ "$USE_GCS" = "true" ]; then
    if [ -z "$GCS_BUCKET_NAME" ]; then
        echo -e "${RED}Error: GCS_BUCKET_NAME is required when USE_GCS=true${NC}"
        echo "Set it with: export GCS_BUCKET_NAME=your-bucket-name"
        exit 1
    fi
    echo "  GCS Bucket: $GCS_BUCKET_NAME"
    echo "  Uploads Path: $GCS_UPLOADS_PREFIX"
    echo "  Outputs Path: $GCS_OUTPUTS_PREFIX"
fi
echo ""

# Ask for confirmation
read -p "Proceed with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Build image name
IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/app:latest"

echo -e "${GREEN}Step 1: Checking if Artifact Registry repository exists...${NC}"
if ! gcloud artifacts repositories describe $REPO_NAME --location=$REGION &>/dev/null; then
    echo -e "${YELLOW}Creating Artifact Registry repository...${NC}"
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$REGION \
        --description="SoraWatermarkCleaner Docker repository"
    echo -e "${GREEN}✓ Repository created${NC}"
else
    echo -e "${GREEN}✓ Repository already exists${NC}"
fi

echo -e "${GREEN}Step 2: Building and pushing Docker image...${NC}"
gcloud builds submit --tag $IMAGE_NAME

echo -e "${GREEN}Step 3: Deploying to Cloud Run...${NC}"

# Build environment variables
ENV_VARS="ENVIRONMENT=production,USE_GCS=$USE_GCS"
if [ "$USE_GCS" = "true" ]; then
    ENV_VARS="$ENV_VARS,GCS_BUCKET_NAME=$GCS_BUCKET_NAME"
    ENV_VARS="$ENV_VARS,GCS_PROJECT_ID=$PROJECT_ID"
    ENV_VARS="$ENV_VARS,GCS_UPLOADS_PREFIX=$GCS_UPLOADS_PREFIX"
    ENV_VARS="$ENV_VARS,GCS_OUTPUTS_PREFIX=$GCS_OUTPUTS_PREFIX"
fi

gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --memory $MEMORY \
    --cpu $CPU \
    --timeout $TIMEOUT \
    --max-instances $MAX_INSTANCES \
    --min-instances $MIN_INSTANCES \
    --port 8080 \
    --set-env-vars "$ENV_VARS"

echo -e "${GREEN}Step 4: Getting service URL...${NC}"
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --platform managed \
    --region $REGION \
    --format 'value(status.url)')

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Service URL:${NC} $SERVICE_URL"
echo ""
echo -e "${YELLOW}Test the deployment:${NC}"
echo "  curl $SERVICE_URL/health"
echo "  curl $SERVICE_URL"
echo ""
echo -e "${YELLOW}View API documentation:${NC}"
echo "  $SERVICE_URL/docs"
echo ""
echo -e "${YELLOW}View logs:${NC}"
echo "  gcloud run services logs tail $SERVICE_NAME --region $REGION"
echo ""
echo -e "${YELLOW}Update configuration:${NC}"
echo "  gcloud run services update $SERVICE_NAME --region $REGION [OPTIONS]"
echo ""

# Save service URL to file
echo $SERVICE_URL > .service_url
echo -e "${GREEN}Service URL saved to .service_url${NC}"

# GCS setup reminder
if [ "$USE_GCS" = "true" ]; then
    echo ""
    echo -e "${YELLOW}=== GCS Storage Configuration ===${NC}"
    echo -e "You're using Google Cloud Storage. Make sure:"
    echo -e "  1. Bucket '${GCS_BUCKET_NAME}' exists"
    echo -e "  2. Cloud Run service account has 'Storage Object Admin' role"
    echo ""
    echo -e "To grant permissions, run:"
    echo -e "  ${GREEN}PROJECT_NUMBER=\$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')${NC}"
    echo -e "  ${GREEN}SERVICE_ACCOUNT=\"\${PROJECT_NUMBER}-compute@developer.gserviceaccount.com\"${NC}"
    echo -e "  ${GREEN}gcloud storage buckets add-iam-policy-binding gs://${GCS_BUCKET_NAME} \\${NC}"
    echo -e "  ${GREEN}    --member=\"serviceAccount:\${SERVICE_ACCOUNT}\" \\${NC}"
    echo -e "  ${GREEN}    --role=\"roles/storage.objectAdmin\"${NC}"
    echo ""
    echo -e "See ${GREEN}GCS_SETUP.md${NC} for detailed setup instructions."
    echo ""
fi

