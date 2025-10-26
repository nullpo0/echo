from psycopg2 import pool


class DB:
    def __init__(self, host='localhost'):
        self.db_pool = pool.SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            host=host,
            dbname='postgres',
            user='postgres',
            password='1234',
            port=5432
        )
        
    def execute(self, query, params=None, fetch=False):
        conn = self.db_pool.getconn()
        cursor = conn.cursor()
        try:
            cursor.execute(query, params)
            if fetch:
                result = cursor.fetchall()
                return result
            else:
                conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            cursor.close()
            self.db_pool.putconn(conn)

db = DB()

def get_db():
    return db
