from fastapi import FastAPI

from sorawm.server.lifespan import lifespan
from sorawm.server.router import router


def init_app():
    app = FastAPI(lifespan=lifespan)
    app.include_router(router)
    
    # Health check endpoint for Cloud Run
    @app.get("/health")
    async def health_check():
        return {"status": "healthy", "service": "sora-watermark-cleaner"}
    
    @app.get("/")
    async def root():
        return {
            "service": "SoraWatermarkCleaner API",
            "version": "0.1.0",
            "endpoints": {
                "docs": "/docs",
                "health": "/health",
                "submit_task": "/submit_remove_task",
                "get_results": "/get_results",
                "download": "/download/{task_id}"
            }
        }
    
    return app
