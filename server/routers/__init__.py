from fastapi import APIRouter, UploadFile, File, Form
from DB import get_db
from predict import get_model