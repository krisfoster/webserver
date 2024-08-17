#!/bin/sh

# rm -rf webserver-jlink
# jlink \
#         --module-path ${JAVA_HOME}/jmods \
#         --add-modules java.base \
#         --verbose \
#         --strip-debug \
#         --compress zip-9 \
#         --no-header-files \
#         --no-man-pages \
#         --strip-java-debug-attributes \
#         --output webserver-jlink

# Distroless Java Base-provides glibc and other libraries needed by the JDK
docker build . -f Dockerfile.distroless-java-base.jlink -t webserver:distroless-java-base.jlink