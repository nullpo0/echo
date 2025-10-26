from routers import APIRouter, get_db
from schemas.web import Login, Students


router = APIRouter(
    prefix="/web",
    tags=["web"],
)

@router.post("/login")
def login(login: Login):
    query = "SELECT * FROM admins"
    db = get_db()
    result = db.execute(query=query, fetch=True)
    if login.password != result[0][0]:
        return {"success": False}
    return {"success": True}


@router.get("/get_stds", response_model=list[Students])
def get_students():
    query = "SELECT * FROM students"
    db = get_db()
    result = db.execute(query=query, fetch=True)
    return [{"s_id": r[0], "name": r[1], "danger_mean": r[2]} for r in result]


@router.get("/get_diaries/{s_id}")
async def get_diaries(s_id: int):
    query = "SELECT * FROM diaries WHERE s_id=%s"
    db = get_db()
    result = db.execute(query=query, params=(s_id,), fetch=True)
    diaries = []
    for r in result:
        img_path = r[4]
        img_url = f"/img/{img_path.split('/')[-1]}" if img_path else None
        
        diaries.append({
            "title": r[2],
            "date": r[3],
            "img": img_url,
            "text": r[5],
            "coment": r[6],
            "danger": r[7]
        })
    
    return diaries