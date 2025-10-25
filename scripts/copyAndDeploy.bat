@echo off
REM Set dind container name or ID
set CONTAINER_NAME=manager
set SCRIPT_NAME=deploy.sh
set FOLDER_NAME=gateway

REM Step 1: Create directories inside the container
echo Creating directories inside %CONTAINER_NAME%...
docker exec %CONTAINER_NAME% mkdir -p /%FOLDER_NAME% /%FOLDER_NAME%/environments /%FOLDER_NAME%/swarm

REM Step 2: Run additional Docker commands
echo Listing files in /gateway...
docker exec %CONTAINER_NAME% ls -l /%FOLDER_NAME%

echo Copying local file into container...
docker cp ../docker/swarm/docker-compose.stack.yml %CONTAINER_NAME%:/%FOLDER_NAME%/swarm/docker-compose.stack.yml
docker cp ../docker/swarm/docker-compose.stack.dev.override.yml %CONTAINER_NAME%:/%FOLDER_NAME%/swarm/docker-compose.stack.dev.override.yml
docker cp ../docker/swarm/docker-compose.stack.prod.override.yml %CONTAINER_NAME%:/%FOLDER_NAME%/swarm/docker-compose.stack.prod.override.yml
docker cp ../docker/environments/dev.env %CONTAINER_NAME%:/%FOLDER_NAME%/environments/dev.env
docker cp ../docker/environments/common.env %CONTAINER_NAME%:/%FOLDER_NAME%/environments/common.env
docker cp deploy.sh %CONTAINER_NAME%:/%FOLDER_NAME%/deploy.sh

REM Step 3: Make script executable and run it inside container
docker exec %CONTAINER_NAME% chmod +x /%FOLDER_NAME%/%SCRIPT_NAME%
docker exec %CONTAINER_NAME% /bin/sh /%FOLDER_NAME%/%SCRIPT_NAME%

echo Done!
pause





