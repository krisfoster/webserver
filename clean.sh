#!/bin/sh
set +e

mvn clean
docker images webserver -q | grep -v TAG | awk '{print($1)}' | xargs docker rmi