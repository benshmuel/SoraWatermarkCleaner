/**
 * Simple usage examples for SoraWatermarkCleaner API Client
 */

const SoraWatermarkCleanerClient = require('./sora-api-client');
const path = require('path');

// Configuration
const CLOUD_RUN_URL = process.env.SORA_API_URL || 'https://your-service-url.run.app';
const USE_AUTH = process.env.USE_AUTH === 'true';

// Initialize client
const client = new SoraWatermarkCleanerClient(CLOUD_RUN_URL, {
  useAuth: USE_AUTH,
  pollInterval: 5000, // Check status every 5 seconds
});

/**
 * Example 1: Simple health check
 */
async function example1_healthCheck() {
  console.log('\n=== Example 1: Health Check ===');
  
  try {
    const health = await client.healthCheck();
    console.log('Service is healthy:', health);
    
    const info = await client.getServiceInfo();
    console.log('Service info:', info);
  } catch (error) {
    console.error('Health check failed:', error.message);
  }
}

/**
 * Example 2: Submit task and poll for status
 */
async function example2_submitAndPoll() {
  console.log('\n=== Example 2: Submit and Poll ===');
  
  const inputVideo = path.join(__dirname, '../resources/dog_vs_sam.mp4');
  
  try {
    // Submit task
    console.log('Submitting video...');
    const taskId = await client.submitTask(inputVideo);
    console.log('Task submitted with ID:', taskId);
    
    // Poll for status
    console.log('Polling for completion...');
    let attempts = 0;
    const maxAttempts = 60; // 5 minutes max
    
    while (attempts < maxAttempts) {
      const status = await client.getTaskStatus(taskId);
      console.log(`Status: ${status.status}, Progress: ${status.progress}%`);
      
      if (status.status === 'FINISHED') {
        console.log('✓ Processing complete!');
        return taskId;
      } else if (status.status === 'ERROR') {
        throw new Error('Processing failed');
      }
      
      await new Promise(resolve => setTimeout(resolve, 5000));
      attempts++;
    }
    
    throw new Error('Timeout waiting for completion');
  } catch (error) {
    console.error('Error:', error.message);
  }
}

/**
 * Example 3: Complete workflow with progress callback
 */
async function example3_completeWorkflow() {
  console.log('\n=== Example 3: Complete Workflow ===');
  
  const inputVideo = path.join(__dirname, '../resources/dog_vs_sam.mp4');
  const outputVideo = path.join(__dirname, 'output_cleaned.mp4');
  
  try {
    const result = await client.removeWatermark(
      inputVideo,
      outputVideo,
      {
        onProgress: (status) => {
          console.log(`[${status.task_id}] ${status.status} - ${status.progress || 0}%`);
        }
      }
    );
    
    console.log('✓ Success!');
    console.log('  Task ID:', result.taskId);
    console.log('  Output:', result.outputPath);
  } catch (error) {
    console.error('Error:', error.message);
  }
}

/**
 * Example 4: Download from existing task
 */
async function example4_downloadExisting(taskId) {
  console.log('\n=== Example 4: Download Existing Task ===');
  
  const outputPath = path.join(__dirname, `download_${taskId}.mp4`);
  
  try {
    console.log('Checking task status...');
    const status = await client.getTaskStatus(taskId);
    
    if (status.status !== 'FINISHED') {
      console.log(`Task not ready yet. Status: ${status.status}`);
      return;
    }
    
    console.log('Downloading video...');
    await client.downloadVideo(taskId, outputPath);
    console.log('✓ Downloaded to:', outputPath);
  } catch (error) {
    console.error('Error:', error.message);
  }
}

/**
 * Example 5: Using with Buffer (for memory-based processing)
 */
async function example5_bufferUpload() {
  console.log('\n=== Example 5: Buffer Upload ===');
  
  const fs = require('fs');
  const inputVideo = path.join(__dirname, '../resources/dog_vs_sam.mp4');
  
  try {
    // Read video into buffer
    const videoBuffer = fs.readFileSync(inputVideo);
    console.log('Video loaded into buffer, size:', videoBuffer.length);
    
    // Submit buffer
    const taskId = await client.submitTask(videoBuffer, 'video.mp4');
    console.log('Task submitted:', taskId);
    
    // Wait for completion
    await client.waitForCompletion(taskId, (status) => {
      console.log(`Progress: ${status.progress}%`);
    });
    
    console.log('✓ Processing complete!');
  } catch (error) {
    console.error('Error:', error.message);
  }
}

// Main function to run examples
async function main() {
  console.log('SoraWatermarkCleaner API Client Examples');
  console.log('========================================');
  console.log('Service URL:', CLOUD_RUN_URL);
  console.log('Authentication:', USE_AUTH ? 'Enabled' : 'Disabled');
  
  // Run examples
  // Uncomment the example you want to run:
  
  await example1_healthCheck();
  
  // await example2_submitAndPoll();
  
  // await example3_completeWorkflow();
  
  // Replace with your task ID:
  // await example4_downloadExisting('your-task-id-here');
  
  // await example5_bufferUpload();
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  example1_healthCheck,
  example2_submitAndPoll,
  example3_completeWorkflow,
  example4_downloadExisting,
  example5_bufferUpload
};

