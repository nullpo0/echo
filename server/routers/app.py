from routers import APIRouter, UploadFile, get_db, File, Form
from schemas.app import Registration
from datetime import date
import os, shutil


router = APIRouter(
    prefix="/app",
    tags=["app"],
)

@router.post("/registration")
def registration(registration: Registration):
    query = "INSERT INTO students (name, danger_mean) VALUES (%s, %s)"
    db = get_db()
    db.execute(query=query, params=(registration.name, 0.0,))
    

@router.post("/upload")
async def upload_diary(
    s_id: int = Form(...),
    title: str = Form(...),
    text: str = Form(...),
    img: UploadFile = File(...)
):
    query = "INSERT INTO diaries (s_id, title, date, img_path, text) VALUES (%s, %s, %s, %s, %s)"
    db = get_db()
    
    img_dir = "img"
    
    filename = f"{s_id}_{int(date.today().strftime('%Y%m%d'))}.jpg"
    file_path = os.path.join(img_dir, filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(img.file, buffer)
    
    db.execute(query=query, params=(s_id, title, date.today(), file_path, text))