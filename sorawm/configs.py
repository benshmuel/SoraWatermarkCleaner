import os
from pathlib import Path

ROOT = Path(__file__).parent.parent


RESOURCES_DIR = ROOT / "resources"
WATER_MARK_TEMPLATE_IMAGE_PATH = RESOURCES_DIR / "watermark_template.png"

WATER_MARK_DETECT_YOLO_WEIGHTS = RESOURCES_DIR / "best.pt"

OUTPUT_DIR = ROOT / "output"

OUTPUT_DIR.mkdir(exist_ok=True, parents=True)


DEFAULT_WATERMARK_REMOVE_MODEL = "lama"

WORKING_DIR = ROOT / "working_dir"
WORKING_DIR.mkdir(exist_ok=True, parents=True)

LOGS_PATH = ROOT / "logs"
LOGS_PATH.mkdir(exist_ok=True, parents=True)

DATA_PATH = ROOT / "data"
DATA_PATH.mkdir(exist_ok=True, parents=True)

SQLITE_PATH = DATA_PATH / "db.sqlite3"

# Google Cloud Storage Configuration
USE_GCS = os.getenv("USE_GCS", "false").lower() == "true"
GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME", None)
GCS_PROJECT_ID = os.getenv("GCS_PROJECT_ID", None)

# Storage paths in GCS (if enabled)
GCS_UPLOADS_PREFIX = os.getenv("GCS_UPLOADS_PREFIX", "uploads")
GCS_OUTPUTS_PREFIX = os.getenv("GCS_OUTPUTS_PREFIX", "outputs")
