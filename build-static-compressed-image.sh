#!/bin/sh
# Compress with UPX
rm -f static.upx-runner
./upx --lzma --best -o runner.static-upx runner.static

# Scratch--fully static and compressed
docker build . -f Dockerfile.scratch.static-upx -t webserver:scratch.static-upx