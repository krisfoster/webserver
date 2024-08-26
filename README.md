# Multi-Cloud Apps with GraalVM - Up and Running

This workshop is for developers looking to understand better how to use [GraalVM Native Image](https://docs.oracle.com/en/graalvm/jdk/22/docs/reference-manual/native-image/) via a Maven plugin and **build size-optimized cloud native Java applications**. 
You are going to discover ways to minimize application footprint by taking advantage of different Native Image linking options and packaging into various base container images. 
Finally, you will learn how to streamline your development process by automating builds with CI/CD pipelines. [to do]

For the demo part, you will run a Spring Boot web server application, hosting the GraalVM website. 
This application is enhanced with the [GraalVM Native Image Maven plugin](https://graalvm.github.io/native-build-tools/latest/index.html). 
GraalVM Native Image can significantly boost the performance and reduce footprint of a Spring Boot application.

In this workshop you will:
- See how to use the GraalVM Native Build tools, [Maven Plugin](https://graalvm.github.io/native-build-tools/latest/maven-plugin.html) in particular.
- Learn how to compile a CLI application ahead-of-time into a native executable and optimize for file size.
- Create native executables within a Docker container.
- Shrink a Docker container size taking advantage of different Native Image containerisation and linking options.
- Use GitHub Actions to automate the build of native executables as part of a CI/CD pipeline. [to do]
- Compare the deployed container images sizes

Note that the website pages add 44M to the container size. 

### Prerequisites

* x86 Linux
* `musl` toolchain
* Container runtime such as [Rancher Desktop](https://docs.rancherdesktop.io/getting-started/installation/) or [Docker](https://www.docker.com/gettingstarted/) installed and running
* [GraalVM for JDK 22](https://www.graalvm.org/downloads/)
* [GraalVM for JDK 23 Early Access Build](https://github.com/graalvm/oracle-graalvm-ea-builds/releases)

Below see the summary of base images that will/can be used in this workshop:

| Image                                         | Purpose                                                      | Size    |
|-----------------------------------------------|--------------------------------------------------------------|---------|
| debian:12-slim                                | For JVM-based applications. Full JDK with required libraries | 785 MB  |
| docker.io/paketo-buildpacks/java-native-image | For JVM-based applications. Full JDK with required libraries |  |
| gcr.io/distroless/java21-debian12             | For JVM-based applications. Full JDK with required libraries | 192 MB  |
| gcr.io/distroless/java-base-debian12          | For JVM-based applications. No JDK. Just required libraries  | 128 MB  |
| gcr.io/distroless/base-debian12               | For mostly statically linked applications. Has libc          | 48.3 MB |
| gcr.io/distroless/static-debian12             | For statically linked applications. No libc                  |  |
| scratch                                       | For statically linked applications. No libc                  | 14.5 MB |

> Distroless container images contain only your application and its runtime dependencies. They do not contain package managers, shells or any other programs you would expect to find in a standard Linux distribution. Learn more in ["Distroless" Container Images](https://github.com/GoogleContainerTools/distroless).

## Setup

Clone this repository with Git and enter the application directory:
```bash
git clone https://github.com/olyagpl/webserver.git 
```
```bash
cd webserver
```

## Step 1: Compile and Run the Application from a JAR File Inside a Container

You are going to compile and run the application from a JAR in a Docker container.
It requires a container image with a full JDK and runtime libraries. 
The Dockerfile, provided for this step, _Dockerfile.distroless-base.uber-jar_, uses a [Debian Slim Linux image](https://github.com/linuxcontainers/debian-slim) and installs Oracle GraalVM for JDK 23 in it.
The entrypoint of this image is equivalent to `java -jar`, so just specify a path to a JAR file in `CMD`.

<!-- Alternatively, you can use [gcr.io/distroless/java21-debian12](https://github.com/GoogleContainerTools/distroless/blob/main/java/README.md) base image. It contains a minimal Linux, OpenJDK 21-based runtime. -->

1. Run the _build-jar.sh_ script:
    ```bash
    ./build-jar.sh
    ```

2.  Once the script finishes, a Docker image _webserver:debian-slim.jar_ should be available. Start the application using `docker run`:
    ```bash
    docker run --rm -p8080:8080 webserver:debian-slim.jar
    ```

3. Open a browser and go to _http://<SERVER_IP>:8080/_, where the `<SERVER_IP>` is the public API address of the host. 
If you are running the example locally, not on a remote host, just open [http://localhost:8080](http://localhost:8080).
You see the GraalVM documentation pages served.

4. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

Let's check the container and runnable JAR file size:

[to do]

The container started in hundreds of milliseconds (<add number>).

## Step 2: Build and Run a Jlink Custom Runtime Image Inside a Container
 
Jlink, or `jlink`, is a tool that generates a custom Java runtime image that contains only the platform modules that are required for your application.
This is one of the approaches to create cloud native applications introduced in Java 11.

Your application does not have to be modular, but you need to figure out which modules you application depends on. 

1. First, run this command to get the classpath:
    ```bash
    ./mvnw dependency:build-classpath -Dmdep.outputFile=cp.txt
    ```
    This will generate a _cp.txt_ file containing the classpath with all the dependencies.

2. Then run `jdeps` with the classpath to check required modules for this Spring Boot application:
    ```bash
    jdeps --ignore-missing-deps -q  --recursive --multi-release 21 --print-module-deps --class-path $(cat cp.txt) target/webserver-0.0.1-SNAPSHOT.jar
    ```
3. Once you have the module names, create a custom runtime using `jlink` for this application as follows:
    ```bash
    jlink \
            --module-path ${JAVA_HOME}/jmods \
            --add-modules java.base,java.compiler,java.desktop,java.instrument,java.management,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.security.jgss,java.sql,jdk.jfr,jdk.unsupported,org.graalvm.nativeimage \
            --verbose \
            --strip-debug \
            --compress zip-9 \
            --no-header-files \
            --no-man-pages \
            --strip-java-debug-attributes \
            --output jlink-jre
    ```
4. Lastly, run the application using the custom runtime:
    ```bash
    ./jlink-jre/bin/java -jar target/webserver-0.0.1-SNAPSHOT.jar 
    ```

However, we prepared the script _build-jlink-runner.sh_ that runs `docker build` using the _Dockerfile.distroless-java-base.jlink_.
The Dockerfile contains a multistage build: first it generates a Jlink custom runtime on a full JDK; then copies the runtime image folder along with static website pages into a Java base container image, and sets the entrypoint:

```
FROM container-registry.oracle.com/graalvm/jdk:22 AS build
COPY . /webserver
WORKDIR /webserver
RUN ./mvnw clean package
RUN ./mvnw dependency:build-classpath -Dmdep.outputFile=cp.txt
RUN jdeps --ignore-missing-deps -q  --recursive --multi-release 21 --print-module-deps --class-path $(cat cp.txt) target/webserver-0.0.1-SNAPSHOT.jar
RUN jlink \
        --module-path ${JAVA_HOME}/jmods \
        --add-modules java.base,java.compiler,java.desktop,java.instrument,java.management,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.security.jgss,java.sql,jdk.jfr,jdk.unsupported,org.graalvm.nativeimage \
        --verbose \
        --strip-debug \
        --compress zip-9 \
        --no-header-files \
        --no-man-pages \
        --strip-java-debug-attributes \
        --output jlink-jre

FROM gcr.io/distroless/java-base-debian12
COPY --from=build /webserver/target/webserver-0.0.1-SNAPSHOT.jar webserver-0.0.1-SNAPSHOT.jar
COPY --from=build /webserver/jlink-jre jlink-jre
EXPOSE 8080
ENTRYPOINT ["jlink-jre/bin/java", "-jar", "webserver-0.0.1-SNAPSHOT.jar"]
```

1. Run the script:
    ```
    ./build-jlink.sh
    ```

2. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 webserver:distroless-java-base.jlink
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.

3. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

Now let's compare file size of build artifacts and container images, and the startup times at this point.
```bash
docker images webserver
```

[to do]

## Step 3: Build and Run a Native Image Inside a Container Using Paketo Buildpacks

> Requires [GraalVM for JDK 22](https://www.graalvm.org/downloads/).

Spring Boot supports building a native image in a container using the [Paketo Buildpack for Oracle](https://github.com/paketo-buildpacks/oracle) which provides GraalVM Native Image. 

The mechanism is that the Paketo builder pulls the [Jammy Tiny Stack image](https://github.com/paketo-buildpacks/builder-jammy-tiny) (Ubuntu Jammy Jellyfish build distroless-like image) which contains no buildpacks. 
Then you point the "builder" image to the "creator" image (see the [Paketo reference documentation](https://paketo.io/docs/)). 
In our case, we would like to point to the [Paketo Buildpack for Oracle](https://github.com/paketo-buildpacks/oracle) explicitly requesting the Native Image tool.

> Note that if you do not specify Oracle's buildpack, it will pull the default buildpack, which can result in reduced performance. 

1. Open the _pom.xml_ file, and find the `spring-boot-maven-plugin` declaration:
    ```xml
    <configuration>
        <image>
        <builder>paketobuildpacks/builder-jammy-buildpackless-tiny</builder>
        <buildpacks>
            <buildpack>paketobuildpacks/oracle</buildpack>
            <buildpack>paketobuildpacks/java-native-image</buildpack>
        </buildpacks>
        </image>
    </configuration>
    ```
    When `java-native-image` is requested, the buildpack downloads Oracle GraalVM, which includes Native Image.

2. Build a native executable for this Spring application using the Paketo buildpack:
    ```bash
    ./mvnw -Pnative spring-boot:build-image
    ```

3. Once the build completes, a container image should be available. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 docker.io/library/webserver:0.0.1-SNAPSHOT
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.

    The server running from the native image started inside a container! The container started in just <add number> milliseconds!

4. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

The [Paketo documentation provides several examples](https://paketo.io/docs/howto/java/#build-an-app-as-a-graalvm-native-image-application) that show you how to build applications with Native Image using buildpacks.

Let's check the size of this container image:
```bash
docker images webserver
```

## Step 4: Build a Native Image Locally and Run Inside a Container (Default Configuration)

> This works for those who want to create a native image on a host machine, and only run inside a container.

Spring Boot 3 has integrated support for GraalVM Native Image, making it easier to set up and configure your project.
[Native Build Tools](https://graalvm.github.io/native-build-tools/latest/index.html) project, maintained by the GraalVM team, provide Maven and Gradle plugins for building native images.
The project configuration already contains all necessary plugins, including [Native Image Maven plugin](https://graalvm.github.io/native-build-tools/latest/index.html):
```xml
<plugin>
    <groupId>org.graalvm.buildtools</groupId>
    <artifactId>native-maven-plugin</artifactId>
</plugin>
```

You can build this web server ahead of time into a native executable, on your host machine, just like this:
```bash
./mvnw -Pnative native:compile
```
The command will compile the application and create a fully dynamically linked native image, `webserver`, in the _target/_ directory.

However, we prepared a script _build-dynamic-image.sh_, for your convenience, that does that and packages this native binary in a distroless base container image with just enough to run the application. No Java Runtime Environment (JRE) is required!

1. Run the script:
    ```
    ./build-dynamic-image.sh
    ```

2. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 webserver:distroless-java-base.dynamic
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.

3. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

Let's check the size of this container image:
```bash
docker images webserver
```

[to do]

## Step 5: Build a Size-Optimized Native Image Locally and Run Inside a Container

_This is where the fun begins._

> Requires [GraalVM for JDK 23 Early Access Build](https://github.com/graalvm/oracle-graalvm-ea-builds/releases). Run:
```bash
wget -q https://github.com/graalvm/oracle-graalvm-ea-builds/releases/download/jdk-23.0.0-ea.23/graalvm-jdk-23.0.0-ea.23_linux-x64_bin.tar.gz && tar -xf graalvm-jdk-23.0.0-ea.23_linux-x64_bin.tar.gz && rm -f graalvm-jdk-23.0.0-ea.23_linux-x64_bin.tar.gz
```
```bash
export JAVA_HOME=/home/opc/graalvm-jdk-23+36.1
```
```bash
export PATH=/home/opc/graalvm-jdk-23+36.1/bin:$PATH
```

Next we are going to build a fully dynamically linked native image **with the file size optimization on**, giving it a different name.
For that, we provide a separate Maven profile to differentiate this run from the default build.
```xml
<profile>
    <id>dynamic-size-optimized</id>
    <build>
        <plugins>
            <plugin>
                <groupId>org.graalvm.buildtools</groupId>
                <artifactId>native-maven-plugin</artifactId>
                <configuration>
                    <imageName>webserver.dynamic</imageName>
                    <buildArgs>
                        <buildArg>-Os</buildArg>
                    </buildArgs>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>
```

The `-Os` option optimizes the resulting native binary for file size. 
`-Os` enables `-O2` optimizations except those that can increase code or executable size significantly. Learn more in [the Native Image documentation](https://www.graalvm.org/jdk23/reference-manual/native-image/optimizations-and-performance/#optimization-levels).

> We will keep the `-Os` optimization for all the subsequent builds. 

The script _build-dynamic-image.sh_, available in this repository for your convenience, creates a native image with fully dynamically linked shared libraries, **optimized for size**, and then packages it in a distroless base container image with just enough to run the application. No Java Runtime Environment (JRE) is required.
The _Dockerfile.distroless-java-base.dynamic-optimized_ Dockerfile copies this native image along with static website pages into a container image, and sets the entrypoint.

1. Run the script:
    ```bash
    ./build-dynamic-image-optimized.sh
    ```

2. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 webserver:distroless-java-base.dynamic-optimized
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.

3. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

Let's check the size of this container image:
```bash
docker images webserver
```

[to do]

## Step 6: Build a Size-Optimized Mostly Static Native Image Locally and Run Inside a Container

> Requires [GraalVM for JDK 23 Early Access Build](https://github.com/graalvm/oracle-graalvm-ea-builds/releases). (See Step 5.)

A mostly-static native image links all the shared libraries on which it relies (`zlib`, JDK-shared static libraries) except the standard C library, `libc`. 
This type of native image is useful for deployment on a distroless base container image.

So now build a mostly statically linked image, by passing the `--static-nolibc` option, and package it into a container image that provides `glibc`. 
A separate Maven profile exists for this build:
```xml
<profile>
    <id>mostly-static</id>
    <build>
        <plugins>
            <plugin>
                <groupId>org.graalvm.buildtools</groupId>
                <artifactId>native-maven-plugin</artifactId>
                <configuration>
                    <imageName>webserver.mostly-static</imageName>
                    <buildArgs>
                        <buildArg>--static-nolibc</buildArg>
                        <buildArg>-Os</buildArg>
                    </buildArgs>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>
```
(The file size optimization is on.)

1. Run the script:
    ```bash
    ./build-mostly-static-image.sh
    ```

2. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 webserver:distroless-base.mostly-static
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.

3. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

Let's check the size of this container image:
```bash
docker images webserver
```

[to do]
 
## Step 7: Build a Size-Optimized Fully Static Native Image Locally and Run Inside a Container

> Requires [GraalVM for JDK 23 Early Access Build](https://github.com/graalvm/oracle-graalvm-ea-builds/releases).  (See Step 5.)

> Requires the `musl` toolchain with `zlib`. Run the following script to download and configure the `musl` toolchain, and install `zlib` into the toolchain:
```bash
./setup-musl.sh
```

A fully static native image is a statically linked binary that you can use without any additional library dependencies.
It is easy to deploy on a slim or distroless container, even a [_scratch_ container](https://hub.docker.com/_/scratch). 
You can create a static native image by statically linking it against `musl-libc`, a lightweight, fast and simple `libc` implementation.

So now build a fully static executable, by passing the `--static --libc=musl` options, and package it into a _scratch_ container. 

A _scratch_ container is a [Docker official image](https://hub.docker.com/_/scratch), useful for building super minimal images.

A separate Maven profile exists for this build:
```xml
<profile>
    <id>fully-static</id>
    <build>
        <plugins>
            <plugin>
                <groupId>org.graalvm.buildtools</groupId>
                <artifactId>native-maven-plugin</artifactId>
                <configuration>
                    <imageName>webserver.static</imageName>
                    <buildArgs>
                        <buildArg>--static --libc=musl</buildArg>
                        <buildArg>-Os</buildArg>
                    </buildArgs>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>
```
(The file size optimization is on.)

1. Run the script:
    ```bash
    ./build-static-image.sh
    ```

2. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 webserver:scratch.static
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.
    
    As a result you get the tiny container image with a fully functional and deployable server application.
    **Note that the website static pages added 44M to the container images size!**

3. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

To summarize this step, the native image that was just created is indeed fully self-contained which can be confirmed by examining it with `ldd`:
```bash
lld target/webserver.static
```

This should result in:
```
not a dynamic executable
```
Which means that the **image does not rely on any libraries in the operating system environment** and can be packaged in the tiniest container!

Let's check the size of this container image:
```bash
docker images webserver
```

[to do]

## Step 8: Compress a Static Native Image with UPX and Run Inside a Container

_What can you do next to reduce the size even more?_

You can compress your native image with [UPX](https://upx.github.io/) - an advanced executable file compressor. 
Then package it into a _scratch_ container. 

1. Download and install UPX:
    ```bash
    ./setup-upx.sh
    ```

2. Compress the fully static executable, created at the previous step, and package it into a _scratch_ container.
    ```bash
    ./build-static-upx-image.sh
    ```

3. Run the container image, mapping the ports:
    ```bash
    docker run --rm -p8080:8080 webserver:scratch.static-upx
    ```
    Open a browser and navigate to _http://<SERVER_IP>:8080/_ or to [localhost:8080/](http://localhost:8080/) to see the GraalVM website running.

4. Stop the running container. Find out the container image ID and stop it:
    ```bash
    docker ps
    ```
    ```bash
    docker stop <image id>
    ```

The application and container image's size were "shrinked" to the minimum.

Let's check the sizes of all deployed containers to see the overall picture:
```bash
docker images webserver
```

[add a table]

Sorted by size, it is clear that the fully static native image, compressed with `upx`, and then packaged on the _scratch_ container is the smallest at just <add number>MB.
The `upx` compressed executable is over xx% smaller from the "uncompressed" one, but note that UPX loads the native executable into the memory, unpackages it, and then compresses.

## Step 9: Clean up

To clean up all images, run the `./clean.sh` script provided for that purpose. 

### Summary 

A fully functional and, at the same time, minimal, Java application was compiled into a native Linux executable and packaged into base, distroless, and scratch-based containers thanks to GraalVM Native Image's support for various linking options.
All the versions of this Spring Boot application are functionally equivalent.

### Learn More

- [Static and Mostly Static Images](https://www.graalvm.org/jdk23/reference-manual/native-image/guides/build-static-executables/)
- [Native Build Tools](https://graalvm.github.io/native-build-tools/latest/index.html)
- [Tiny Java Containers by Shaun Smith at DevoxxUK 2022](https://youtu.be/6wYrAtngIVo)
- [Paketo Buildpacks](https://paketo.io/docs/)