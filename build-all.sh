#!/bin/sh 

./build-dynamic-image.sh
./build-mostly-static-image.sh
./build-static-image.sh
./build-static-upx-image.sh
./build-jlink.sh

echo "Generated Executables"
ls -lh webserver*

echo "Generated Docker Container Images"
docker images webserver
