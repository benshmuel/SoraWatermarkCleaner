# Node.js Integration for SoraWatermarkCleaner

This package provides a complete Node.js client library and examples for integrating with the SoraWatermarkCleaner Cloud Run API.

## Contents

- `sora-api-client.js` - Main client library
- `example-usage.js` - Simple usage examples
- `example-express-route.js` - Express.js integration example
- `package.json` - Dependencies
- `.env.example` - Environment configuration template

## Installation

1. Install dependencies:

```bash
npm install
```

2. Create your `.env` file:

```bash
cp .env.example .env
```

3. Update `.env` with your Cloud Run service URL:

```env
SORA_API_URL=https://your-service-url.run.app
USE_AUTH=false
```

## Quick Start

### Basic Usage

```javascript
const SoraWatermarkCleanerClient = require('./sora-api-client');

const client = new SoraWatermarkCleanerClient('https://your-service-url.run.app');

// Complete workflow
await client.removeWatermark(
  'input.mp4',
  'output.mp4',
  {
    onProgress: (status) => {
      console.log(`${status.status} - ${status.progress}%`);
    }
  }
);
```

### Step-by-Step Process

```javascript
// 1. Submit task
const taskId = await client.submitTask('video.mp4');

// 2. Check status
const status = await client.getTaskStatus(taskId);

// 3. Wait for completion
await client.waitForCompletion(taskId, (status) => {
  console.log(`Progress: ${status.progress}%`);
});

// 4. Download result
await client.downloadVideo(taskId, 'output.mp4');
```

## API Reference

### Constructor

```javascript
new SoraWatermarkCleanerClient(serviceUrl, options)
```

**Parameters:**
- `serviceUrl` (string): Cloud Run service URL
- `options` (object, optional):
  - `useAuth` (boolean): Enable Google Cloud authentication
  - `uploadTimeout` (number): Upload timeout in ms (default: 300000)
  - `pollInterval` (number): Status polling interval in ms (default: 5000)

### Methods

#### `healthCheck()`
Check if the service is healthy.

```javascript
const health = await client.healthCheck();
// Returns: { status: "healthy", service: "sora-watermark-cleaner" }
```

#### `getServiceInfo()`
Get service information and available endpoints.

```javascript
const info = await client.getServiceInfo();
```

#### `submitTask(video, filename)`
Submit a video for watermark removal.

**Parameters:**
- `video`: File path (string), Buffer, or ReadStream
- `filename`: Filename (optional, required for Buffer)

**Returns:** Task ID (string)

```javascript
// From file path
const taskId = await client.submitTask('/path/to/video.mp4');

// From buffer
const buffer = fs.readFileSync('video.mp4');
const taskId = await client.submitTask(buffer, 'video.mp4');

// From stream
const stream = fs.createReadStream('video.mp4');
const taskId = await client.submitTask(stream, 'video.mp4');
```

#### `getTaskStatus(taskId)`
Get the current status of a task.

**Returns:** Status object
```javascript
{
  task_id: "abc123",
  status: "PROCESSING",  // PENDING, PROCESSING, FINISHED, ERROR
  progress: 45           // 0-100
}
```

#### `waitForCompletion(taskId, onProgress)`
Wait for a task to complete, with optional progress callback.

**Parameters:**
- `taskId`: Task ID
- `onProgress`: Optional callback function

```javascript
await client.waitForCompletion(taskId, (status) => {
  console.log(`${status.status}: ${status.progress}%`);
});
```

#### `downloadVideo(taskId, outputPath)`
Download the processed video.

```javascript
await client.downloadVideo(taskId, './output.mp4');
```

#### `removeWatermark(inputVideo, outputPath, options)`
Complete workflow: upload, process, and download.

**Parameters:**
- `inputVideo`: File path, Buffer, or ReadStream
- `outputPath`: Where to save the cleaned video
- `options`: Optional configuration
  - `onProgress`: Progress callback function
  - `filename`: Filename for Buffer inputs

```javascript
const result = await client.removeWatermark(
  'input.mp4',
  'output.mp4',
  {
    onProgress: (status) => {
      console.log(`${status.progress}%`);
    }
  }
);
// Returns: { taskId, outputPath, success: true }
```

## Express.js Integration

See `example-express-route.js` for a complete Express.js server with endpoints for:

- `POST /api/watermark/remove` - Upload and start processing
- `GET /api/watermark/status/:taskId` - Check status
- `GET /api/watermark/download/:taskId` - Download result
- `POST /api/watermark/process` - Complete workflow (blocking)

### Running the Express Example

```bash
# Set your Cloud Run URL
export SORA_API_URL=https://your-service-url.run.app

# Run the server
node example-express-route.js
```

### Using the Express API

```bash
# Upload video
curl -X POST http://localhost:3000/api/watermark/remove \
  -F "video=@video.mp4"

# Check status
curl http://localhost:3000/api/watermark/status/TASK_ID

# Download result
curl -o cleaned.mp4 http://localhost:3000/api/watermark/download/TASK_ID
```

## Authentication

For authenticated Cloud Run services:

```javascript
const client = new SoraWatermarkCleanerClient(
  'https://your-service-url.run.app',
  { useAuth: true }
);
```

**Requirements:**
- Application Default Credentials configured
- Service account with `roles/run.invoker` permission

**Setup:**
```bash
# Set up application default credentials
gcloud auth application-default login

# Grant service account permission
gcloud run services add-iam-policy-binding sora-watermark-cleaner \
  --region=us-central1 \
  --member="serviceAccount:YOUR_SA@project.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

## Error Handling

```javascript
try {
  const result = await client.removeWatermark('input.mp4', 'output.mp4');
  console.log('Success:', result);
} catch (error) {
  if (error.message.includes('not found')) {
    console.error('Video file not found');
  } else if (error.message.includes('Task failed')) {
    console.error('Processing failed on server');
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

## Examples

Run the examples:

```bash
# Set your service URL
export SORA_API_URL=https://your-service-url.run.app

# Run examples
node example-usage.js
```

The examples demonstrate:
1. Health check
2. Submit and poll
3. Complete workflow with progress
4. Download existing task
5. Upload from buffer

## App Engine Integration

For Google App Engine applications:

**app.yaml:**
```yaml
runtime: nodejs20
env_variables:
  SORA_API_URL: "https://your-service-url.run.app"
  USE_AUTH: "true"
```

**Code:**
```javascript
const client = new SoraWatermarkCleanerClient(
  process.env.SORA_API_URL,
  { useAuth: true }
);
```

## Tips

1. **Large Files**: Increase `uploadTimeout` for large videos
2. **Progress Updates**: Use `onProgress` callback for user feedback
3. **Async Processing**: Use separate submit/poll endpoints for long videos
4. **Error Handling**: Always wrap API calls in try-catch blocks
5. **Timeouts**: Set appropriate timeouts based on video length

## Support

For issues with:
- **This client library**: Check the code in `sora-api-client.js`
- **Cloud Run service**: Check logs with `gcloud run services logs tail`
- **Authentication**: Verify credentials with `gcloud auth list`

## License

Apache License 2.0

