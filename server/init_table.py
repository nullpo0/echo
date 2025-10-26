from DB import get_db

db = get_db()

query1 = '''
CREATE TABLE admins(
    password VARCHAR(100)
)
'''

db.execute(query=query1)

query2 = '''
INSERT INTO admins (password) VALUES ('1234')
'''

db.execute(query=query2)

query3 = '''
CREATE TABLE students(
    s_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    danger_mean FLOAT
)
'''

db.execute(query=query3)

query4 = '''
CREATE TABLE diaries(
    d_id SERIAL PRIMARY KEY,
    s_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    date DATE NOT NULL,
    img_path TEXT,
    text TEXT,
    comment TEXT,
    danger INTEGER,
    
    CONSTRAINT fk_student
        FOREIGN KEY (s_id)
        REFERENCES students(s_id)
        ON DELETE CASCADE
)
'''

db.execute(query=query4)