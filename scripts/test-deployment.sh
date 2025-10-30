#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Testing SoraWatermarkCleaner Deployment ===${NC}"

# Get service URL
if [ -f .service_url ]; then
    SERVICE_URL=$(cat .service_url)
    echo -e "${GREEN}Service URL:${NC} $SERVICE_URL"
else
    read -p "Enter your Cloud Run service URL: " SERVICE_URL
fi

echo ""
echo -e "${YELLOW}Test 1: Health Check${NC}"
curl -s "$SERVICE_URL/health" | jq '.' || echo -e "${RED}Health check failed${NC}"

echo ""
echo -e "${YELLOW}Test 2: Root Endpoint${NC}"
curl -s "$SERVICE_URL/" | jq '.' || echo -e "${RED}Root endpoint failed${NC}"

echo ""
echo -e "${YELLOW}Test 3: Check if video test file exists${NC}"
TEST_VIDEO="resources/dog_vs_sam.mp4"
if [ ! -f "$TEST_VIDEO" ]; then
    echo -e "${RED}Test video not found at $TEST_VIDEO${NC}"
    echo "Skipping video upload test"
    exit 0
fi

echo -e "${GREEN}Found test video${NC}"
echo ""
echo -e "${YELLOW}Test 4: Submit Watermark Removal Task${NC}"
RESPONSE=$(curl -s -X POST "$SERVICE_URL/submit_remove_task" \
    -F "video=@$TEST_VIDEO")

echo "$RESPONSE" | jq '.'

TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')
if [ "$TASK_ID" == "null" ] || [ -z "$TASK_ID" ]; then
    echo -e "${RED}Failed to submit task${NC}"
    exit 1
fi

echo -e "${GREEN}Task ID: $TASK_ID${NC}"

echo ""
echo -e "${YELLOW}Test 5: Check Task Status${NC}"
for i in {1..5}; do
    echo "Checking status (attempt $i/5)..."
    STATUS_RESPONSE=$(curl -s "$SERVICE_URL/get_results?remove_task_id=$TASK_ID")
    echo "$STATUS_RESPONSE" | jq '.'
    
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
    
    if [ "$STATUS" == "FINISHED" ]; then
        echo -e "${GREEN}✓ Task completed successfully!${NC}"
        
        echo ""
        echo -e "${YELLOW}Test 6: Download Result${NC}"
        OUTPUT_FILE="test_output_$(date +%s).mp4"
        curl -o "$OUTPUT_FILE" "$SERVICE_URL/download/$TASK_ID"
        
        if [ -f "$OUTPUT_FILE" ]; then
            FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
            echo -e "${GREEN}✓ Video downloaded successfully: $OUTPUT_FILE (Size: $FILE_SIZE)${NC}"
        else
            echo -e "${RED}Failed to download video${NC}"
        fi
        
        break
    elif [ "$STATUS" == "ERROR" ]; then
        echo -e "${RED}Task failed with error${NC}"
        break
    fi
    
    if [ $i -lt 5 ]; then
        echo "Waiting 10 seconds before next check..."
        sleep 10
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}View full API documentation:${NC}"
echo "  $SERVICE_URL/docs"
echo ""
echo -e "${YELLOW}View logs:${NC}"
echo "  gcloud run services logs tail sora-watermark-cleaner --region \$(gcloud config get-value run/region)"
echo ""

