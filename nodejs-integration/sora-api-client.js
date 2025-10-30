/**
 * SoraWatermarkCleaner API Client for Node.js
 * 
 * This client library provides a simple interface to interact with the
 * SoraWatermarkCleaner Cloud Run service.
 */

const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
const { GoogleAuth } = require('google-auth-library');

class SoraWatermarkCleanerClient {
  /**
   * Create a new client instance
   * @param {string} serviceUrl - The Cloud Run service URL
   * @param {Object} options - Configuration options
   * @param {boolean} options.useAuth - Whether to use Google Cloud authentication
   * @param {number} options.uploadTimeout - Timeout for file uploads in ms (default: 300000 = 5min)
   * @param {number} options.pollInterval - Polling interval in ms (default: 5000 = 5sec)
   */
  constructor(serviceUrl, options = {}) {
    this.serviceUrl = serviceUrl.replace(/\/$/, ''); // Remove trailing slash
    this.useAuth = options.useAuth || false;
    this.uploadTimeout = options.uploadTimeout || 300000; // 5 minutes default
    this.pollInterval = options.pollInterval || 5000; // 5 seconds default
    this.auth = null;
    
    if (this.useAuth) {
      this.auth = new GoogleAuth();
    }
  }

  /**
   * Get authentication token for Cloud Run
   * @private
   */
  async _getAuthToken() {
    if (!this.useAuth || !this.auth) {
      return null;
    }

    try {
      const client = await this.auth.getIdTokenClient(this.serviceUrl);
      const token = await client.idTokenProvider.fetchIdToken(this.serviceUrl);
      return token;
    } catch (error) {
      console.error('Error getting auth token:', error.message);
      throw new Error('Failed to authenticate with Cloud Run');
    }
  }

  /**
   * Get headers for authenticated requests
   * @private
   */
  async _getHeaders(additionalHeaders = {}) {
    const headers = { ...additionalHeaders };
    
    if (this.useAuth) {
      const token = await this._getAuthToken();
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
    }
    
    return headers;
  }

  /**
   * Check if the service is healthy
   * @returns {Promise<Object>} Health status
   */
  async healthCheck() {
    try {
      const headers = await this._getHeaders();
      const response = await axios.get(`${this.serviceUrl}/health`, { headers });
      return response.data;
    } catch (error) {
      throw new Error(`Health check failed: ${error.message}`);
    }
  }

  /**
   * Get service information
   * @returns {Promise<Object>} Service info
   */
  async getServiceInfo() {
    try {
      const headers = await this._getHeaders();
      const response = await axios.get(`${this.serviceUrl}/`, { headers });
      return response.data;
    } catch (error) {
      throw new Error(`Failed to get service info: ${error.message}`);
    }
  }

  /**
   * Submit a video for watermark removal
   * @param {string|Buffer|ReadStream} video - Path to video file, Buffer, or ReadStream
   * @param {string} filename - Optional filename (required if passing Buffer)
   * @returns {Promise<string>} Task ID
   */
  async submitTask(video, filename = 'video.mp4') {
    try {
      const form = new FormData();
      
      // Handle different input types
      if (typeof video === 'string') {
        // File path
        form.append('video', fs.createReadStream(video));
      } else if (Buffer.isBuffer(video)) {
        // Buffer
        form.append('video', video, { filename });
      } else {
        // Assume it's a stream
        form.append('video', video, { filename });
      }

      const headers = await this._getHeaders(form.getHeaders());
      
      const response = await axios.post(
        `${this.serviceUrl}/submit_remove_task`,
        form,
        {
          headers,
          timeout: this.uploadTimeout,
          maxBodyLength: Infinity,
          maxContentLength: Infinity
        }
      );
      
      if (!response.data.task_id) {
        throw new Error('No task ID returned from server');
      }
      
      return response.data.task_id;
    } catch (error) {
      if (error.code === 'ENOENT') {
        throw new Error(`Video file not found: ${video}`);
      }
      throw new Error(`Failed to submit task: ${error.message}`);
    }
  }

  /**
   * Get the status of a task
   * @param {string} taskId - The task ID
   * @returns {Promise<Object>} Task status object
   * @returns {string} .task_id - Task ID
   * @returns {string} .status - Status (PENDING, PROCESSING, FINISHED, ERROR)
   * @returns {number} .progress - Progress percentage (0-100)
   * @returns {string} .download_url - Download URL (when finished)
   */
  async getTaskStatus(taskId) {
    try {
      const headers = await this._getHeaders();
      const response = await axios.get(
        `${this.serviceUrl}/get_results`,
        {
          params: { remove_task_id: taskId },
          headers
        }
      );
      
      return response.data;
    } catch (error) {
      if (error.response && error.response.status === 404) {
        throw new Error(`Task not found: ${taskId}`);
      }
      throw new Error(`Failed to get task status: ${error.message}`);
    }
  }

  /**
   * Wait for a task to complete
   * @param {string} taskId - The task ID
   * @param {Function} onProgress - Optional callback for progress updates
   * @returns {Promise<Object>} Final task status
   */
  async waitForCompletion(taskId, onProgress = null) {
    return new Promise((resolve, reject) => {
      const checkStatus = async () => {
        try {
          const status = await this.getTaskStatus(taskId);
          
          if (onProgress) {
            onProgress(status);
          }
          
          if (status.status === 'FINISHED') {
            resolve(status);
          } else if (status.status === 'ERROR') {
            reject(new Error('Task failed with error'));
          } else {
            // Continue polling
            setTimeout(checkStatus, this.pollInterval);
          }
        } catch (error) {
          reject(error);
        }
      };
      
      checkStatus();
    });
  }

  /**
   * Download the processed video
   * @param {string} taskId - The task ID
   * @param {string} outputPath - Path to save the video
   * @returns {Promise<string>} Path to the downloaded file
   */
  async downloadVideo(taskId, outputPath) {
    try {
      const headers = await this._getHeaders();
      const response = await axios.get(
        `${this.serviceUrl}/download/${taskId}`,
        {
          headers,
          responseType: 'stream'
        }
      );
      
      const writer = fs.createWriteStream(outputPath);
      response.data.pipe(writer);
      
      return new Promise((resolve, reject) => {
        writer.on('finish', () => resolve(outputPath));
        writer.on('error', reject);
      });
    } catch (error) {
      if (error.response && error.response.status === 404) {
        throw new Error(`Video not found for task: ${taskId}`);
      }
      if (error.response && error.response.status === 400) {
        throw new Error('Task not finished yet');
      }
      throw new Error(`Failed to download video: ${error.message}`);
    }
  }

  /**
   * Complete workflow: upload, wait for completion, and download
   * @param {string|Buffer|ReadStream} inputVideo - Input video
   * @param {string} outputPath - Path to save the cleaned video
   * @param {Object} options - Options
   * @param {Function} options.onProgress - Progress callback
   * @param {string} options.filename - Filename for Buffer inputs
   * @returns {Promise<Object>} Result object with taskId and outputPath
   */
  async removeWatermark(inputVideo, outputPath, options = {}) {
    const { onProgress, filename } = options;
    
    try {
      // Step 1: Submit task
      const taskId = await this.submitTask(inputVideo, filename);
      
      if (onProgress) {
        onProgress({ status: 'SUBMITTED', task_id: taskId });
      }
      
      // Step 2: Wait for completion
      await this.waitForCompletion(taskId, onProgress);
      
      // Step 3: Download result
      await this.downloadVideo(taskId, outputPath);
      
      return {
        taskId,
        outputPath,
        success: true
      };
    } catch (error) {
      throw new Error(`Watermark removal failed: ${error.message}`);
    }
  }
}

module.exports = SoraWatermarkCleanerClient;

