# Quick Start: Deploy to Google Cloud Run

Get your SoraWatermarkCleaner API running on Google Cloud Run in 3 simple steps!

## 🚀 Three-Step Deployment

### Step 1: Setup Google Cloud (5 minutes)

Run the interactive setup script:

```bash
./scripts/setup-gcloud.sh
```

This will:
- Authenticate your Google Cloud account
- Set up your project
- Enable required APIs
- Configure Docker authentication

### Step 2: Deploy to Cloud Run (10-15 minutes)

Deploy with a single command:

```bash
./deploy.sh
```

The script will:
- Create a Docker registry
- Build your container image
- Deploy to Cloud Run
- Display your service URL

**Your service URL will be saved to `.service_url` file**

### Step 3: Integrate with Node.js (5 minutes)

Copy the Node.js client to your App Engine project:

```bash
# Copy integration package
cp -r nodejs-integration /path/to/your/app-engine-project/

# Install dependencies
cd /path/to/your/app-engine-project/nodejs-integration
npm install

# Configure
echo "SORA_API_URL=$(cat .service_url)" > .env
```

Use in your code:

```javascript
const SoraWatermarkCleanerClient = require('./nodejs-integration/sora-api-client');

const client = new SoraWatermarkCleanerClient(process.env.SORA_API_URL);

// Remove watermark from video
await client.removeWatermark('input.mp4', 'output.mp4', {
  onProgress: (status) => {
    console.log(`Progress: ${status.progress}%`);
  }
});
```

## ✅ Test Your Deployment

Run the test script:

```bash
./scripts/test-deployment.sh
```

Or test manually:

```bash
SERVICE_URL=$(cat .service_url)

# Health check
curl $SERVICE_URL/health

# API documentation
open $SERVICE_URL/docs
```

## 📝 What Was Created

Your repository now includes:

### Cloud Run Files
- `Dockerfile` - Container definition
- `.dockerignore` - Build optimization
- `.gcloudignore` - Deployment optimization

### Deployment Scripts
- `deploy.sh` - One-command deployment
- `scripts/setup-gcloud.sh` - Google Cloud setup
- `scripts/test-deployment.sh` - Deployment testing

### Node.js Integration
- `nodejs-integration/sora-api-client.js` - Client library
- `nodejs-integration/example-usage.js` - Usage examples
- `nodejs-integration/example-express-route.js` - Express integration
- `nodejs-integration/README.md` - Detailed documentation

### Code Updates
- `start_server.py` - Now reads PORT from environment
- `sorawm/server/app.py` - Added health check endpoints

### Documentation
- `DEPLOYMENT.md` - Complete deployment guide
- `QUICKSTART.md` - This file!

## 🔧 Common Commands

```bash
# Redeploy after changes
./deploy.sh

# View logs
gcloud run services logs tail sora-watermark-cleaner

# Update resources
gcloud run services update sora-watermark-cleaner \
    --memory 8Gi --cpu 4

# Get service URL
cat .service_url
```

## 📖 Next Steps

1. **Read the full documentation**: See `DEPLOYMENT.md` for advanced topics
2. **Explore Node.js examples**: Check `nodejs-integration/README.md`
3. **Enable authentication**: For production use (see DEPLOYMENT.md)
4. **Set up monitoring**: View metrics in Cloud Console
5. **Optimize costs**: Adjust resources based on usage

## 💡 Tips

- **First deployment takes 10-15 minutes** (building ML dependencies)
- **Subsequent deployments are faster** (5-7 minutes)
- **Keep min-instances=0 for development** to minimize costs
- **Use min-instances=1 for production** to avoid cold starts
- **Test locally first** with Docker if needed

## 🆘 Need Help?

- **Cloud Run Issues**: Check `gcloud run services logs tail sora-watermark-cleaner`
- **Deployment Errors**: Run with `--verbosity=debug` flag
- **Node.js Integration**: See examples in `nodejs-integration/`
- **Full Guide**: Read `DEPLOYMENT.md`

## 🎯 Architecture Overview

```
┌─────────────────┐
│   App Engine    │
│   (Node.js)     │
└────────┬────────┘
         │
         │ HTTP/REST API
         │
         ▼
┌─────────────────┐
│   Cloud Run     │
│   (Python)      │
│                 │
│  ┌───────────┐  │
│  │ FastAPI   │  │
│  ├───────────┤  │
│  │ YOLOv11   │  │
│  │ Detection │  │
│  ├───────────┤  │
│  │   LAMA    │  │
│  │ Inpainting│  │
│  └───────────┘  │
└─────────────────┘
```

## 📊 Resource Requirements

| Video Size | Memory | CPU | Est. Time |
|------------|--------|-----|-----------|
| < 100MB    | 2Gi    | 1   | 2-5 min   |
| 100-500MB  | 4Gi    | 2   | 5-15 min  |
| > 500MB    | 8Gi    | 4   | 15-30 min |

## 🎉 You're All Set!

Your SoraWatermarkCleaner API is now running on Google Cloud Run and ready to be called from your Node.js App Engine application!

**Service URL**: Check `.service_url` file or run:
```bash
cat .service_url
```

**API Documentation**: `<YOUR_SERVICE_URL>/docs`

Happy coding! 🚀

