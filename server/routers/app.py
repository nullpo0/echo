from routers import APIRouter, UploadFile, get_db, get_model, File, Form
from schemas.app import Registration
from datetime import date
import os, shutil


router = APIRouter(
    prefix="/app",
    tags=["app"],
)

@router.post("/registration")
def registration(registration: Registration):
    query = "INSERT INTO students (name, danger_mean) VALUES (%s, %s) RETURNING s_id"
    db = get_db()
    s_id = db.execute(query=query, params=(registration.name, 0.0,), fetch=True)
    return {"s_id": s_id}
    

@router.post("/upload")
async def upload_diary(
    s_id: int = Form(...),
    title: str = Form(...),
    text: str = Form(...),
    img: UploadFile = File(...)
):
    query = "INSERT INTO diaries (s_id, title, date, img_path, text, danger) VALUES (%s, %s, %s, %s, %s, %s)"
    db = get_db()
    model = get_model()
    
    img_dir = "img"
    
    filename = f"{s_id}_{int(date.today().strftime('%Y%m%d'))}.jpg"
    file_path = os.path.join(img_dir, filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(img.file, buffer)
    
    danger = model.predict(file_path)
    
    db.execute(query=query, params=(s_id, title, date.today(), file_path, text, danger))