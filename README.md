# [CNU 심화프로젝트랩] 매아리 - 매일 아이 이해하기 : 그림일기 기반 아동학대 탐지 시스템 및 앱
저학년 아동과 교사를 대상으로 하며 아동학대 위험을 감지하는 시스템 개발 프로젝트입니다. 어플에서 아동이 작성한 그림일기를 AI가 분석하고 교사는 웹에서 현황을 모니터링할 수 있게 합니다.

## Getting Started
```
git clone https://github.com/nullpo0/echo.git
cd echo
```
## Caution
* 모든 작업은 develop branch에서 이루어져야 합니다. 기능 구현 branch도 develop branch로부터 생성되어야 합니다.
> 현재 branch 확인
> ```
> git branch
> ```

> branch 생성 (ex : 앱의 그림판을 구현하는 상황)
> ```
> git branch app/drawingBoard
> ```

> branch 이동 (ex : develop branch로 이동)
> ```
> git switch develop
> ```

> merge (ex : 작업을 마친 app/drawingBoard branch를 develop branch에 병합)
> ```
> git switch develop
> git pull origin develop
> git merge app/drawingBoard
> ```
## etc
figma : https://www.figma.com/design/YRccdlsDbmDnlhocmyxYJ1/Untitled?node-id=1-3&t=MVHTdni6gB1p2DIK-1

## init(server side)
0. WSL2 ubuntu-24.04 기준으로 작성됨.

1. docker 설치
```
source scripts/docker_install.sh
```
2. postgresql 이미지 다운로드 & 컨테이너 실행
```
source scripts/postgresql_install.sh
```
3. 가상환경 venv 구축
```
source scripts/venv.sh
```
4. DB 초기 테이블 구축
```
cd server
python init_table.py
```