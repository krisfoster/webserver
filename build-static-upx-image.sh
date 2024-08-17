#!/bin/sh

rm -f webserver.static-upx

# Compress with UPX
./upx --lzma --best -o webserver.static-upx webserver.static

# Scratch--fully static and compressed
docker build . -f Dockerfile.scratch.static-upx -t webserver:scratch.static-upx