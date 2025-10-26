from schemas import BaseModel


class Login(BaseModel):
    password: str

class Students(BaseModel):
    s_id: int
    name: str
    danger_mean: float