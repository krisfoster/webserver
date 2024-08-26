#!/bin/sh
set +e

./mvnw clean
docker images webserver -q | grep -v TAG | awk '{print($1)}' | xargs docker rmi