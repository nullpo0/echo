import torch
from torchvision import transforms, models
from PIL import Image
import torch.nn as nn


class Predictor:
    def __init__(self):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model = models.efficientnet_b0(weights=None)
        self.model.classifier[1] = nn.Linear(self.model.classifier[1].in_features, 1)
        self.model.load_state_dict(torch.load("emotion_model.pth", map_location=self.device))
        self.model.eval().to(self.device)
        
        self.transform = transforms.Compose([
            transforms.Resize((224,224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.5,0.5,0.5], std=[0.5,0.5,0.5])
            ])
        
    def predict(self, img_path):
        image = Image.open(img_path).convert("RGB")
        img = self.transform(image).unsqueeze(0).to(self.device)

        with torch.no_grad():
            output = self.model(img).item()
            prob = torch.sigmoid(torch.tensor(output)).item()
            
        negative = (1 - prob) * 100
        
        return round(negative, 2)
    
model = Predictor()

def get_model():
    return model