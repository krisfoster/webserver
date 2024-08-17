#!/bin/sh

# Compile linking zlib and JDK shared libraries except the standard C library (libc); optimize for size
mvn -Dmaven.test.skip=true -Pmostly-static native:compile

# Distroless Base (provides glibc)
docker build . -f Dockerfile.distroless-base.mostly -t webserver:distroless-base.mostly-static