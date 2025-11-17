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

query5 = '''
CREATE OR REPLACE FUNCTION update_student_danger_mean()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        UPDATE students
        SET danger_mean = (
            SELECT AVG(danger)::FLOAT
            FROM diaries
            WHERE s_id = NEW.s_id
        )
        WHERE s_id = NEW.s_id;

    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE students
        SET danger_mean = (
            SELECT AVG(danger)::FLOAT
            FROM diaries
            WHERE s_id = OLD.s_id
        )
        WHERE s_id = OLD.s_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
'''

db.execute(query=query5)

query6 = '''
CREATE TRIGGER diaries_danger_mean_trigger
AFTER INSERT OR UPDATE OR DELETE
ON diaries
FOR EACH ROW
EXECUTE FUNCTION update_student_danger_mean();
'''

db.execute(query=query6)