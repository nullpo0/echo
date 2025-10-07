# Introduction
서버, DB, 모델 개발에 대한 폴더입니다. 서버에서는 어플 및 웹에서 API 호출에 대한 response를 담당하고 모델 inference를 담당합니다. DB에서는 학생들의 정보 및 그림을 저장합니다. 모델은 학생들의 그림일기를 분석합니다.
## Specification
1. API를 통한 app-sever-web pipeline 구축
2. DB 구축
3. 모델 학습 및 추론 모델과 서버간 연결
4. (option) 학생 커뮤니티 서버
5. ...
## Tech Stack
[제안]
* server : FastAPI
* DB : PostgreSQL