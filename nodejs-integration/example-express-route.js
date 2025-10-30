/**
 * Example Express.js routes for SoraWatermarkCleaner integration
 * 
 * This file shows how to integrate the SoraWatermarkCleaner API
 * into an Express.js application.
 */

const express = require('express');
const multer = require('multer');
const path = require('path');
const SoraWatermarkCleanerClient = require('./sora-api-client');

const app = express();
const upload = multer({ dest: 'uploads/' });

// Initialize the client
// Get this URL after deploying to Cloud Run
const CLOUD_RUN_URL = process.env.SORA_API_URL || 'https://your-service-url.run.app';
const USE_AUTH = process.env.USE_AUTH === 'true';

const soraClient = new SoraWatermarkCleanerClient(CLOUD_RUN_URL, {
  useAuth: USE_AUTH
});

// Store active tasks (in production, use Redis or a database)
const activeTasks = new Map();

/**
 * Health check endpoint
 */
app.get('/api/health', async (req, res) => {
  try {
    const health = await soraClient.healthCheck();
    res.json({ status: 'ok', sora_service: health });
  } catch (error) {
    res.status(503).json({ status: 'error', message: error.message });
  }
});

/**
 * Upload video and start watermark removal
 * POST /api/watermark/remove
 * Body: multipart/form-data with 'video' field
 */
app.post('/api/watermark/remove', upload.single('video'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No video file provided' });
    }

    // Submit task to Cloud Run
    const taskId = await soraClient.submitTask(req.file.path);
    
    // Store task info
    activeTasks.set(taskId, {
      originalName: req.file.originalname,
      uploadedAt: new Date(),
      status: 'PENDING'
    });

    res.json({
      success: true,
      taskId,
      message: 'Video submitted for processing',
      statusUrl: `/api/watermark/status/${taskId}`
    });
  } catch (error) {
    console.error('Error submitting video:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Check task status
 * GET /api/watermark/status/:taskId
 */
app.get('/api/watermark/status/:taskId', async (req, res) => {
  try {
    const { taskId } = req.params;
    
    const status = await soraClient.getTaskStatus(taskId);
    
    // Update local cache
    if (activeTasks.has(taskId)) {
      activeTasks.get(taskId).status = status.status;
    }

    res.json({
      taskId,
      status: status.status,
      progress: status.progress,
      downloadUrl: status.status === 'FINISHED' ? `/api/watermark/download/${taskId}` : null
    });
  } catch (error) {
    console.error('Error getting status:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Download processed video
 * GET /api/watermark/download/:taskId
 */
app.get('/api/watermark/download/:taskId', async (req, res) => {
  try {
    const { taskId } = req.params;
    
    // Check if task is finished
    const status = await soraClient.getTaskStatus(taskId);
    if (status.status !== 'FINISHED') {
      return res.status(400).json({ 
        error: 'Video not ready yet',
        status: status.status,
        progress: status.progress
      });
    }

    const outputPath = path.join('downloads', `${taskId}.mp4`);
    await soraClient.downloadVideo(taskId, outputPath);
    
    // Send file to client
    res.download(outputPath, 'watermark_removed.mp4', (err) => {
      if (err) {
        console.error('Error sending file:', err);
      }
    });
  } catch (error) {
    console.error('Error downloading video:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Complete workflow endpoint - handles everything in one request
 * POST /api/watermark/process
 * Body: multipart/form-data with 'video' field
 * 
 * Note: This keeps the connection open until processing is complete.
 * Use the separate endpoints above for long-running videos.
 */
app.post('/api/watermark/process', upload.single('video'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No video file provided' });
    }

    const outputPath = path.join('downloads', `processed_${Date.now()}.mp4`);
    
    // Process with progress updates (optional)
    const result = await soraClient.removeWatermark(
      req.file.path,
      outputPath,
      {
        onProgress: (status) => {
          console.log(`Task ${status.task_id}: ${status.status} - ${status.progress}%`);
        }
      }
    );

    // Send the processed video
    res.download(result.outputPath, 'watermark_removed.mp4');
  } catch (error) {
    console.error('Error processing video:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * List all active tasks
 * GET /api/watermark/tasks
 */
app.get('/api/watermark/tasks', (req, res) => {
  const tasks = Array.from(activeTasks.entries()).map(([id, info]) => ({
    taskId: id,
    ...info
  }));
  
  res.json({ tasks });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Sora API URL: ${CLOUD_RUN_URL}`);
  console.log(`Authentication: ${USE_AUTH ? 'Enabled' : 'Disabled'}`);
});

module.exports = app;

