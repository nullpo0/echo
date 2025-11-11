from routers import APIRouter, get_db, get_gemini
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
            "d_id": r[0],
            "title": r[2],
            "date": r[3],
            "img": img_url,
            "text": r[5],
            "coment": r[6],
            "danger": r[7]
        })
    
    return diaries

@router.get("/get_analysis/{d_id}")
async def get_analysis(d_id: int):
    query = "SELECT * FROM diaries WHERE d_id=%s"
    db = get_db()
    gemini = get_gemini()
    
    result = db.execute(query=query, params=(d_id,), fetch=True)
    
    img_path = result[0][4]
    text = result[0][5]
    
    prompt = f'''
    이 그림은 아동학대 위험도 측정 모델에서 아동학대 의심 아동 그림으로 분류되었어.
    아래 text는 이 그림을 그린 아동이 함께 작성한 일기야. 참고해서 이 그림을 분석하고 아동의 심리 상태를 분석해줘.
    text : {text}
    '''
    
    res = gemini.inference(image_path=img_path, prompt=prompt)
    
    return {"response": res}