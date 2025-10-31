import asyncio
from asyncio import Queue
from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

from loguru import logger
from sqlalchemy import select

from sorawm.configs import (
    WORKING_DIR,
    USE_GCS,
    GCS_BUCKET_NAME,
    GCS_UPLOADS_PREFIX,
    GCS_OUTPUTS_PREFIX,
)
from sorawm.core import SoraWM
from sorawm.iopaint.file_manager.storage_backends import (
    FilesystemStorageBackend,
    GCSStorageBackend,
)
from sorawm.server.db import get_session
from sorawm.server.models import Task
from sorawm.server.schemas import Status, WMRemoveResults


class WMRemoveTaskWorker:
    def __init__(self) -> None:
        self.queue = Queue()
        self.sora_wm = None
        self.output_dir = WORKING_DIR
        self.upload_dir = WORKING_DIR / "uploads"
        self.upload_dir.mkdir(exist_ok=True, parents=True)
        
        # Initialize storage backend
        self.use_gcs = USE_GCS
        if self.use_gcs:
            if not GCS_BUCKET_NAME:
                raise ValueError("GCS_BUCKET_NAME must be set when USE_GCS=true")
            logger.info(f"Using Google Cloud Storage with bucket: {GCS_BUCKET_NAME}")
            self.storage_backend = GCSStorageBackend(bucket_name=GCS_BUCKET_NAME)
        else:
            logger.info("Using local filesystem storage")
            self.storage_backend = FilesystemStorageBackend()

    async def initialize(self):
        logger.info("Initializing SoraWM models...")
        self.sora_wm = SoraWM()
        logger.info("SoraWM models initialized")

    async def create_task(self) -> str:
        task_uuid = str(uuid4())
        async with get_session() as session:
            task = Task(
                id=task_uuid,
                video_path="",  # 暂时为空，后续会更新
                status=Status.UPLOADING,
                percentage=0,
            )
            session.add(task)
        logger.info(f"Task {task_uuid} created with UPLOADING status")
        return task_uuid

    async def queue_task(self, task_id: str, video_path: Path):
        # If using GCS, upload the video to GCS and use GCS path
        if self.use_gcs:
            gcs_path = f"{GCS_UPLOADS_PREFIX}/{task_id}_{video_path.name}"
            logger.info(f"Uploading video to GCS: {gcs_path}")
            with open(video_path, "rb") as f:
                await asyncio.to_thread(
                    self.storage_backend.save, gcs_path, f.read()
                )
            # Use a Path object with the GCS path for consistency
            storage_path = Path(gcs_path)
            logger.info(f"Video uploaded to GCS successfully")
        else:
            storage_path = video_path
        
        async with get_session() as session:
            result = await session.execute(select(Task).where(Task.id == task_id))
            task = result.scalar_one()
            task.video_path = str(storage_path)
            task.status = Status.PROCESSING
            task.percentage = 0

        self.queue.put_nowait((task_id, storage_path))
        logger.info(f"Task {task_id} queued for processing: {storage_path}")

    async def mark_task_error(self, task_id: str, error_msg: str):
        async with get_session() as session:
            result = await session.execute(select(Task).where(Task.id == task_id))
            task = result.scalar_one_or_none()
            if task:
                task.status = Status.ERROR
                task.percentage = 0
        logger.error(f"Task {task_id} marked as ERROR: {error_msg}")

    async def run(self):
        logger.info("Worker started, waiting for tasks...")
        while True:
            task_uuid, video_path = await self.queue.get()
            logger.info(f"Processing task {task_uuid}: {video_path}")
            
            local_input_path = None
            local_output_path = None

            try:
                # If using GCS, download the input video to local temp location
                if self.use_gcs:
                    logger.info(f"Downloading input video from GCS: {video_path}")
                    local_input_path = self.upload_dir / f"temp_{task_uuid}{video_path.suffix}"
                    video_data = await asyncio.to_thread(
                        self.storage_backend.read, str(video_path)
                    )
                    local_input_path.write_bytes(video_data)
                    logger.info(f"Downloaded to local temp: {local_input_path}")
                else:
                    local_input_path = video_path
                
                timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
                file_suffix = video_path.suffix
                output_filename = f"{task_uuid}_{timestamp}{file_suffix}"
                local_output_path = self.output_dir / output_filename

                async with get_session() as session:
                    result = await session.execute(
                        select(Task).where(Task.id == task_uuid)
                    )
                    task = result.scalar_one()
                    task.status = Status.PROCESSING
                    task.percentage = 10

                loop = asyncio.get_event_loop()

                def progress_callback(percentage: int):
                    asyncio.run_coroutine_threadsafe(
                        self._update_progress(task_uuid, percentage), loop
                    )

                # Process the video
                await asyncio.to_thread(
                    self.sora_wm.run, local_input_path, local_output_path, progress_callback
                )

                # If using GCS, upload the output video
                if self.use_gcs:
                    logger.info(f"Uploading output video to GCS")
                    gcs_output_path = f"{GCS_OUTPUTS_PREFIX}/{output_filename}"
                    with open(local_output_path, "rb") as f:
                        await asyncio.to_thread(
                            self.storage_backend.save, gcs_output_path, f.read()
                        )
                    final_output_path = gcs_output_path
                    logger.info(f"Uploaded to GCS: {gcs_output_path}")
                    
                    # Clean up local temp files
                    if local_input_path and local_input_path.exists():
                        local_input_path.unlink()
                    if local_output_path and local_output_path.exists():
                        local_output_path.unlink()
                else:
                    final_output_path = str(local_output_path)

                async with get_session() as session:
                    result = await session.execute(
                        select(Task).where(Task.id == task_uuid)
                    )
                    task = result.scalar_one()
                    task.status = Status.FINISHED
                    task.percentage = 100
                    task.output_path = final_output_path
                    task.download_url = f"/download/{task_uuid}"

                logger.info(
                    f"Task {task_uuid} completed successfully, output: {final_output_path}"
                )

            except Exception as e:
                logger.error(f"Error processing task {task_uuid}: {e}")
                
                # Clean up temp files on error
                if self.use_gcs:
                    if local_input_path and local_input_path.exists():
                        try:
                            local_input_path.unlink()
                        except Exception as cleanup_err:
                            logger.error(f"Error cleaning up temp input: {cleanup_err}")
                    if local_output_path and local_output_path.exists():
                        try:
                            local_output_path.unlink()
                        except Exception as cleanup_err:
                            logger.error(f"Error cleaning up temp output: {cleanup_err}")
                
                async with get_session() as session:
                    result = await session.execute(
                        select(Task).where(Task.id == task_uuid)
                    )
                    task = result.scalar_one()
                    task.status = Status.ERROR
                    task.percentage = 0

            finally:
                self.queue.task_done()

    async def _update_progress(self, task_id: str, percentage: int):
        try:
            async with get_session() as session:
                result = await session.execute(select(Task).where(Task.id == task_id))
                task = result.scalar_one_or_none()
                if task:
                    task.percentage = percentage
                    logger.debug(f"Task {task_id} progress updated to {percentage}%")
        except Exception as e:
            logger.error(f"Error updating progress for task {task_id}: {e}")

    async def get_task_status(self, task_id: str) -> WMRemoveResults | None:
        async with get_session() as session:
            result = await session.execute(select(Task).where(Task.id == task_id))
            task = result.scalar_one_or_none()
            if task is None:
                return None
            
            # Generate signed URL directly for finished tasks when using GCS
            download_url = None
            if task.status == Status.FINISHED and task.output_path:
                if self.use_gcs:
                    # Return signed GCS URL directly for video playback
                    download_url = await self.get_download_url(task_id)
                else:
                    # Local storage - return download endpoint
                    download_url = task.download_url
            
            return WMRemoveResults(
                percentage=task.percentage,
                status=Status(task.status),
                download_url=download_url,
            )

    async def get_output_path(self, task_id: str) -> Path | None:
        async with get_session() as session:
            result = await session.execute(select(Task).where(Task.id == task_id))
            task = result.scalar_one_or_none()
            if task is None or task.output_path is None:
                return None
            return Path(task.output_path)
    
    async def get_download_url(self, task_id: str) -> str | None:
        """Get download URL for a completed task.
        
        For GCS: Returns a signed URL valid for 1 hour
        For local: Returns the regular download endpoint
        """
        async with get_session() as session:
            result = await session.execute(select(Task).where(Task.id == task_id))
            task = result.scalar_one_or_none()
            if task is None or task.output_path is None:
                return None
            
            if self.use_gcs:
                # Generate signed URL for GCS
                try:
                    signed_url = await asyncio.to_thread(
                        self.storage_backend.get_signed_url,
                        task.output_path,
                        timedelta(hours=1)
                    )
                    return signed_url
                except Exception as e:
                    logger.error(f"Error generating signed URL for task {task_id}: {e}")
                    return None
            else:
                # Return local download endpoint
                return f"/download/{task_id}"


worker = WMRemoveTaskWorker()
