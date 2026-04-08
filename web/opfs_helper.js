/**
 * OPFS (Origin Private File System) Helper for Flutter Gemma
 * 
 * Provides OPFS-based storage for large model files (>2GB) to bypass
 * ArrayBuffer memory limitations in browsers.
 */
window.flutterGemmaOPFS = {
  /**
   * Check if a model is already cached in OPFS
   * @param {string} filename - Model filename (used as cache key)
   * @returns {Promise<boolean>} True if model exists in OPFS
   */
  async isModelCached(filename) {
    try {
      const opfs = await navigator.storage.getDirectory();
      await opfs.getFileHandle(filename);
      return true;
    } catch (error) {
      // File doesn't exist or OPFS not supported
      return false;
    }
  },

  /**
   * Get the size of a cached model
   * @param {string} filename - Model filename
   * @returns {Promise<number|null>} File size in bytes, or null if not found
   */
  async getCachedModelSize(filename) {
    try {
      const opfs = await navigator.storage.getDirectory();
      const handle = await opfs.getFileHandle(filename);
      const file = await handle.getFile();
      return file.size;
    } catch (error) {
      return null;
    }
  },

  /**
   * Download a model file to OPFS with progress tracking and cancellation support
   */
  async downloadToOPFS(url, filename, authToken, onProgress, abortSignal) {
    let writable = null;
    let reader = null;
    try {
      console.log(`[OPFS] Starting download: ${filename} from ${url}`);
      const estimate = await navigator.storage.estimate();
      
      const fetchOptions = {};
      if (authToken) { fetchOptions.headers = { 'Authorization': `Bearer ${authToken}` }; }
      if (abortSignal) { fetchOptions.signal = abortSignal; }

      const response = await fetch(url, fetchOptions);
      if (!response.ok) { throw new Error(`HTTP ${response.status}: ${response.statusText}`); }
      
      const contentLength = parseInt(response.headers.get('content-length') || '0');
      
      const opfs = await navigator.storage.getDirectory();
      const fileHandle = await opfs.getFileHandle(filename, { create: true });
      writable = await fileHandle.createWritable();

      reader = response.body.getReader();
      let bytesReceived = 0;
      let lastProgressPercent = 0;

      while (true) {
        if (abortSignal?.aborted) { throw new DOMException('Download aborted', 'AbortError'); }
        const { done, value } = await reader.read();
        if (done) break;

        await writable.write(value);
        bytesReceived += value.length;

        if (contentLength > 0) {
          const progressPercent = Math.round((bytesReceived / contentLength) * 100);
          if (progressPercent !== lastProgressPercent) {
            onProgress(progressPercent);
            lastProgressPercent = progressPercent;
          }
        }
      }

      await writable.close();
      writable = null;
      console.log(`[OPFS] Download complete: ${filename}`);
      return true;
    } catch (error) {
      if (reader) { try { await reader.cancel(); } catch (e) {} }
      if (writable) { try { await writable.abort(); } catch (e) {} }
      throw error;
    }
  },

  /**
   * Get a ReadableStreamDefaultReader for a cached model file
   */
  async getStreamReader(filename) {
    try {
      const opfs = await navigator.storage.getDirectory();
      const handle = await opfs.getFileHandle(filename);
      const file = await handle.getFile();
      return file.stream().getReader();
    } catch (error) {
      console.error(`[OPFS] Failed to get stream reader: ${error.message}`);
      throw new Error(`Model not found in OPFS: ${filename}`);
    }
  },

  /**
   * Delete a model from OPFS
   */
  async deleteModel(filename) {
    try {
      const opfs = await navigator.storage.getDirectory();
      await opfs.removeEntry(filename);
      console.log(`[OPFS] Deleted: ${filename}`);
    } catch (error) {
      console.error(`[OPFS] Failed to delete ${filename}: ${error.message}`);
      throw error;
    }
  },

  /**
   * Get current storage statistics
   */
  async getStorageStats() {
    const estimate = await navigator.storage.estimate();
    return { usage: estimate.usage || 0, quota: estimate.quota || 0 };
  },

  /**
   * Clear all models from OPFS
   */
  async clearAll() {
    try {
      const opfs = await navigator.storage.getDirectory();
      let count = 0;
      for await (const [name, handle] of opfs.entries()) {
        if (handle.kind === 'file') {
          await opfs.removeEntry(name);
          count++;
        }
      }
      console.log(`[OPFS] Cleared ${count} files`);
      return count;
    } catch (error) {
      console.error(`[OPFS] Failed to clear: ${error.message}`);
      throw error;
    }
  }
};

if (typeof navigator !== 'undefined' && navigator.storage && navigator.storage.getDirectory) {
  console.log('[OPFS] Origin Private File System available');
} else {
  console.warn('[OPFS] Origin Private File System NOT available');
}
