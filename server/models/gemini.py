import os
from dotenv import load_dotenv
from google import genai
from PIL import Image

load_dotenv()

class Gemini:
    def __init__(self):
        self.model_name = "gemini-2.5-flash-lite"
        self.APIKEY = os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=self.APIKEY)
        
    def inference(self, image_path, prompt):
        img = Image.open(image_path)
        
        content = [img, prompt]
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=content
        )
        
        return response.text
    
gemini = Gemini()

def get_gemini():
    return gemini