from DB import get_db
import random


db = get_db()

stds = ["인이준", "왕예진", "백준우", "장이안", "설민수", "허서우", "고유준", "함하린", "연유준", "노예은", "노이민", "손예린", "도서현", "백도하", "송소율", "편유진", "이현수", "채민서", "원수아", "정시윤"]


for i in stds:
    q = "INSERT INTO students (name, danger_mean) VALUES (%s, %s)"
    db.execute(q,(i, 0.0))

for i in range(7):
    for j in range(len(stds)):
        img_path = f"{j+1}_2025111{i}.jpg"
        danger = random.randint(0, 100)
        date = f"2025-11-1{i}"
        q = "INSERT INTO diaries (s_id, title, date, img_path, text, danger) VALUES (%s, %s, %s, %s, %s, %s)"
        db.execute(q, (j+1, "title", date, img_path, "text", danger))