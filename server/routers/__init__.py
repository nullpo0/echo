from fastapi import APIRouter, UploadFile, File, Form
from DB import get_db
from models.predict import get_model
from models.gemini import get_gemini