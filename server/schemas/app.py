from schemas import BaseModel


class Registration(BaseModel):
    name: str
    
    
class Upload(BaseModel): # unused
    s_id: int
    title: str
    text: str