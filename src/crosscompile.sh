INSTANCE_NAME="piratejni"
EXISTING_CONTAINER_ID=$(docker ps -aqf "name=${INSTANCE_NAME}")
EXISTING_RUNNING_CONTAINER_ID=$(docker ps -aqf "name=${INSTANCE_NAME}" --filter status=running)

if [ -z "${EXISTING_RUNNING_CONTAINER_ID}" ]; then

    # Container not running - start it
    echo "Starting new container ${INSTANCE_NAME}..."
    docker rm "${INSTANCE_NAME}"
    docker run -v "$(pwd)":/build --name "${INSTANCE_NAME}" -it "${INSTANCE_NAME}" "./main/build.sh"

else
    # Already running
    echo "${INSTANCE_NAME} is already running with container ID ${EXISTING_CONTAINER_ID}. Doing nothing."
fi
