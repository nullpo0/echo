docker pull postgres:latest

docker run --name pgDB -p 5432:5432 -e POSTGRES_PASSWORD=1234 -v pgdata:/var/lib/postgresql -d postgres