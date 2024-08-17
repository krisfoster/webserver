#!/bin/sh

TOOLCHAIN_DIR=`pwd`/x86_64-linux-musl-native
CC=${TOOLCHAIN_DIR}/bin/gcc
PATH=${TOOLCHAIN_DIR}/bin:${PATH}

# Create a statically linked binary that can be used without any additional library dependencies; optimize for size
mvn -Dmaven.test.skip=true -Pfully-static native:compile

# Scratch-nothing
docker build . -f Dockerfile.scratch.static -t webserver:scratch.static

# Alpine-no glibc
# docker build . -f Dockerfile.alpine.static -t webserver:alpine.static