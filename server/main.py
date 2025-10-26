from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import web, app
from fastapi.staticfiles import StaticFiles

fastapp = FastAPI()


fastapp.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

fastapp.include_router(app.router)
fastapp.include_router(web.router)

fastapp.mount("/img", StaticFiles(directory="img"), name="img")