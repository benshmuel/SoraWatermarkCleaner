# Copy from https://github.com/silentsokolov/flask-thumbnails/blob/master/flask_thumbnails/storage_backends.py
import errno
import os
from abc import ABC, abstractmethod
from datetime import timedelta
from typing import Optional


class BaseStorageBackend(ABC):
    def __init__(self, app=None):
        self.app = app

    @abstractmethod
    def read(self, filepath, mode="rb", **kwargs):
        raise NotImplementedError

    @abstractmethod
    def exists(self, filepath):
        raise NotImplementedError

    @abstractmethod
    def save(self, filepath, data):
        raise NotImplementedError


class FilesystemStorageBackend(BaseStorageBackend):
    def read(self, filepath, mode="rb", **kwargs):
        with open(filepath, mode) as f:  # pylint: disable=unspecified-encoding
            return f.read()

    def exists(self, filepath):
        return os.path.exists(filepath)

    def save(self, filepath, data):
        directory = os.path.dirname(filepath)

        if not os.path.exists(directory):
            try:
                os.makedirs(directory)
            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise

        if not os.path.isdir(directory):
            raise IOError("{} is not a directory".format(directory))

        with open(filepath, "wb") as f:
            f.write(data)


class GCSStorageBackend(BaseStorageBackend):
    """Google Cloud Storage backend for storing files in GCS buckets."""
    
    def __init__(self, app=None, bucket_name: Optional[str] = None):
        super().__init__(app)
        if not bucket_name:
            raise ValueError("bucket_name is required for GCSStorageBackend")
        
        try:
            from google.cloud import storage
            self.storage = storage
        except ImportError:
            raise ImportError(
                "google-cloud-storage is required for GCSStorageBackend. "
                "Install it with: pip install google-cloud-storage"
            )
        
        self.bucket_name = bucket_name
        self._client = None
        self._bucket = None
    
    @property
    def client(self):
        """Lazy initialization of GCS client."""
        if self._client is None:
            self._client = self.storage.Client()
        return self._client
    
    @property
    def bucket(self):
        """Lazy initialization of GCS bucket."""
        if self._bucket is None:
            self._bucket = self.client.bucket(self.bucket_name)
        return self._bucket
    
    def read(self, filepath, mode="rb", **kwargs):
        """Read file from GCS bucket."""
        # Remove leading slash if present
        blob_name = filepath.lstrip("/")
        blob = self.bucket.blob(blob_name)
        
        if not blob.exists():
            raise FileNotFoundError(f"File not found in GCS: {blob_name}")
        
        return blob.download_as_bytes()
    
    def exists(self, filepath):
        """Check if file exists in GCS bucket."""
        blob_name = filepath.lstrip("/")
        blob = self.bucket.blob(blob_name)
        return blob.exists()
    
    def save(self, filepath, data):
        """Save file to GCS bucket."""
        blob_name = filepath.lstrip("/")
        blob = self.bucket.blob(blob_name)
        
        # Handle both bytes and file-like objects
        if isinstance(data, bytes):
            blob.upload_from_string(data)
        else:
            blob.upload_from_file(data)
    
    def get_signed_url(self, filepath, expiration: timedelta = timedelta(hours=1)) -> str:
        """Generate a signed URL for temporary access to a file."""
        blob_name = filepath.lstrip("/")
        blob = self.bucket.blob(blob_name)
        
        url = blob.generate_signed_url(
            version="v4",
            expiration=expiration,
            method="GET"
        )
        return url
    
    def delete(self, filepath):
        """Delete file from GCS bucket."""
        blob_name = filepath.lstrip("/")
        blob = self.bucket.blob(blob_name)
        if blob.exists():
            blob.delete()
