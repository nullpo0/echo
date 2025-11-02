set -e

source venv/bin/activate

CONTAINER_NAME="pgDB"

STATUS=$(docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Status}}")

if [[ $STATUS == *"Up"* ]]; then
    :
else
    if [[ -n $STATUS ]]; then
        docker start "$CONTAINER_NAME"
    else
        echo not exist container. please download postgreSQL image.
    fi
fi

cd server

uvicorn main:fastapp --reload