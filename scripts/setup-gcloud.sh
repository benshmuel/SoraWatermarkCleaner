#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Google Cloud Setup for SoraWatermarkCleaner ===${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo -e "${GREEN}✓ gcloud CLI is installed${NC}"

# Check authentication
echo -e "${YELLOW}Checking authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
    echo -e "${YELLOW}Not authenticated. Starting authentication...${NC}"
    gcloud auth login
else
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "${GREEN}✓ Authenticated as: $ACTIVE_ACCOUNT${NC}"
fi

# Get or set project
echo ""
echo -e "${YELLOW}Setting up project...${NC}"
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -z "$CURRENT_PROJECT" ]; then
    echo "No project currently set."
    read -p "Enter your GCP Project ID: " PROJECT_ID
    gcloud config set project $PROJECT_ID
else
    echo -e "Current project: ${GREEN}$CURRENT_PROJECT${NC}"
    read -p "Use this project? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your GCP Project ID: " PROJECT_ID
        gcloud config set project $PROJECT_ID
    else
        PROJECT_ID=$CURRENT_PROJECT
    fi
fi

echo -e "${GREEN}✓ Project set to: $PROJECT_ID${NC}"

# Set region
echo ""
echo -e "${YELLOW}Setting default region...${NC}"
REGION=${REGION:-us-central1}
read -p "Enter region (default: us-central1): " INPUT_REGION
if [ ! -z "$INPUT_REGION" ]; then
    REGION=$INPUT_REGION
fi
gcloud config set run/region $REGION
echo -e "${GREEN}✓ Region set to: $REGION${NC}"

# Enable required APIs
echo ""
echo -e "${YELLOW}Enabling required Google Cloud APIs...${NC}"
echo "This may take a few minutes..."

APIS=(
    "cloudbuild.googleapis.com"
    "run.googleapis.com"
    "artifactregistry.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

for API in "${APIS[@]}"; do
    echo -n "  Enabling $API... "
    if gcloud services enable $API 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (may already be enabled)${NC}"
    fi
done

# Configure Docker authentication
echo ""
echo -e "${YELLOW}Configuring Docker authentication...${NC}"
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet
echo -e "${GREEN}✓ Docker authentication configured${NC}"

# Create service account for App Engine (optional)
echo ""
read -p "Create service account for App Engine authentication? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SA_NAME="app-engine-caller"
    SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
    
    echo -e "${YELLOW}Creating service account: $SA_NAME${NC}"
    
    if gcloud iam service-accounts describe $SA_EMAIL &>/dev/null; then
        echo -e "${YELLOW}Service account already exists${NC}"
    else
        gcloud iam service-accounts create $SA_NAME \
            --display-name="App Engine API Caller" \
            --description="Service account for App Engine to call Cloud Run services"
        echo -e "${GREEN}✓ Service account created${NC}"
    fi
    
    # Save service account email
    echo $SA_EMAIL > .service_account
    echo -e "${GREEN}Service account email saved to .service_account${NC}"
    echo ""
    echo -e "${YELLOW}Note: After deploying your service, grant this service account access with:${NC}"
    echo "gcloud run services add-iam-policy-binding sora-watermark-cleaner \\"
    echo "    --region=$REGION \\"
    echo "    --member=\"serviceAccount:$SA_EMAIL\" \\"
    echo "    --role=\"roles/run.invoker\""
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Project ID:${NC} $PROJECT_ID"
echo -e "${GREEN}Region:${NC} $REGION"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run deployment script:"
echo "   ./deploy.sh"
echo ""
echo "2. Test the deployment:"
echo "   ./scripts/test-deployment.sh"
echo ""
echo "3. Check logs:"
echo "   gcloud run services logs tail sora-watermark-cleaner --region $REGION"
echo ""

