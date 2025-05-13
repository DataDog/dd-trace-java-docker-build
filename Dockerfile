# syntax=docker/dockerfile:1.6

ARG LATEST_VERSION
FROM eclipse-temurin:${LATEST_VERSION}-jdk-noble AS temurin-latest

# Intermediate image used to prune cruft from JDKs and squash them all.
FROM ubuntu:24.04 AS all-jdk
ARG LATEST_VERSION

COPY --from=eclipse-temurin:8-jdk-jammy /opt/java/openjdk /usr/lib/jvm/8
COPY --from=eclipse-temurin:11-jdk-jammy /opt/java/openjdk /usr/lib/jvm/11
COPY --from=eclipse-temurin:17-jdk-jammy /opt/java/openjdk /usr/lib/jvm/17
COPY --from=eclipse-temurin:21-jdk-jammy /opt/java/openjdk /usr/lib/jvm/21
COPY --from=temurin-latest /opt/java/openjdk /usr/lib/jvm/${LATEST_VERSION}

COPY --from=azul/zulu-openjdk:7 /usr/lib/jvm/zulu7 /usr/lib/jvm/7
COPY --from=azul/zulu-openjdk:8 /usr/lib/jvm/zulu8 /usr/lib/jvm/zulu8
COPY --from=azul/zulu-openjdk:11 /usr/lib/jvm/zulu11 /usr/lib/jvm/zulu11

COPY --from=ibmjava:8-sdk /opt/ibm/java /usr/lib/jvm/ibm8

COPY --from=ibm-semeru-runtimes:open-8-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru8
COPY --from=ibm-semeru-runtimes:open-11-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru11
COPY --from=ibm-semeru-runtimes:open-17-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru17

COPY --from=ghcr.io/graalvm/native-image-community:17-ol9 /usr/lib64/graalvm/graalvm-community-java17 /usr/lib/jvm/graalvm17
COPY --from=ghcr.io/graalvm/native-image-community:21-ol9 /usr/lib64/graalvm/graalvm-community-java21 /usr/lib/jvm/graalvm21

RUN apt-get update && \
    apt-get install -y curl tar apt-transport-https ca-certificates gnupg wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# See: https://gist.github.com/wavezhang/ba8425f24a968ec9b2a8619d7c2d86a6
RUN <<-EOT
	set -eux
	mkdir -p /usr/lib/jvm/oracle8
	curl -L --fail "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=246284_165374ff4ea84ef0bbd821706e29b123" | tar -xvzf - -C /usr/lib/jvm/oracle8 --strip-components 1
EOT

# Install Ubuntu's OpenJDK 17 and fix broken symlinks:
# some files in /usr/lib/jvm/ubuntu17 are symlinks to /etc/java-17-openjdk/, so we just copy all symlinks targets.
RUN <<-EOT
	set -eux
	apt-get update
	apt-get install -y openjdk-17-jdk
	mv /usr/lib/jvm/java-17-openjdk-amd64 /usr/lib/jvm/ubuntu17
	mkdir -p /usr/lib/jvm/ubuntu17/conf/ /usr/lib/jvm/ubuntu17/lib/
	cp -rf --remove-destination /etc/java-17-openjdk/* /usr/lib/jvm/ubuntu17/conf/
	cp -rf --remove-destination /etc/java-17-openjdk/* /usr/lib/jvm/ubuntu17/lib/
	cp -f --remove-destination /etc/java-17-openjdk/jvm-amd64.cfg /usr/lib/jvm/ubuntu17/lib/
EOT

# Remove cruft from JDKs that is not used in the build process.
RUN <<-EOT
	rm -rf \
	  /usr/lib/jvm/*/man \
	  /usr/lib/jvm/*/lib/src.zip \
	  /usr/lib/jvm/*/demo \
	  /usr/lib/jvm/*/sample \
	  /usr/lib/jvm/graalvm*/lib/installer
EOT

FROM scratch AS default-jdk
ARG LATEST_VERSION

COPY --from=all-jdk /usr/lib/jvm/8 /usr/lib/jvm/8
COPY --from=all-jdk /usr/lib/jvm/11 /usr/lib/jvm/11
COPY --from=all-jdk /usr/lib/jvm/17 /usr/lib/jvm/17
COPY --from=all-jdk /usr/lib/jvm/21 /usr/lib/jvm/21
COPY --from=all-jdk /usr/lib/jvm/${LATEST_VERSION} /usr/lib/jvm/${LATEST_VERSION}

# Base image with minimum requirements to build the project.
# Based on the latest Ubuntu LTS image.
FROM ubuntu:24.04 AS base
ARG LATEST_VERSION
ENV LATEST_VERSION=${LATEST_VERSION}

# https://docs.github.com/en/packages/learn-github-packages/connecting-a-repository-to-a-package
LABEL org.opencontainers.image.source=https://github.com/DataDog/dd-trace-java-docker-build

RUN apt-get update && \
    apt-get install -y curl apt-transport-https ca-certificates gnupg \
    socat less debian-goodies autossh ca-certificates-java python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /usr/local/lib/docker/cli-plugins /usr/local/bin

# Install Docker Compose plugin and yq YAML processor
RUN <<-EOT
	set -eu
	dockerPluginDir=/usr/local/lib/docker/cli-plugins
	curl -sSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o $dockerPluginDir/docker-compose
	chmod +x $dockerPluginDir/docker-compose
	curl -sSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture).tar.gz" | tar -xz -C /usr/local/bin --wildcards --no-anchored 'yq_linux_*'
	YQ_PATH=$(find /usr/local/bin -name 'yq_linux_*')
	mv "$YQ_PATH" /usr/local/bin/yq
	chown root:root /usr/local/bin/yq
EOT

COPY --from=default-jdk /usr/lib/jvm /usr/lib/jvm

COPY autoforward.py /usr/local/bin/autoforward

# Install the following tools
# - awscli: AWS CLI
# - autoforward dependencies: tool to forward request to a remote Docker deamon
# - datadog-ci: Datadog CI tool
RUN <<-EOT
	set -eux
	apt-get update
	pip3 install --break-system-packages awscli requests requests-unixsocket2
	pip3 cache purge
	chmod +x /usr/local/bin/autoforward
	curl -L --fail "https://github.com/DataDog/datadog-ci/releases/latest/download/datadog-ci_linux-x64" --output "/usr/local/bin/datadog-ci"
	chmod +x /usr/local/bin/datadog-ci
	apt-get clean
	rm -rf /var/lib/apt/lists/*
EOT

# IBM specific env variables
ENV IBM_JAVA_OPTIONS="-XX:+UseContainerSupport"

# Set some odd looking variables, since their default values are wrong and it is unclear how they are used.
ENV JAVA_DEBIAN_VERSION=unused
ENV JAVA_VERSION=unused

# Set up environment variables to point to all jvms we have.
ENV JAVA_8_HOME=/usr/lib/jvm/8
ENV JAVA_11_HOME=/usr/lib/jvm/11
ENV JAVA_17_HOME=/usr/lib/jvm/17
ENV JAVA_21_HOME=/usr/lib/jvm/21
ENV JAVA_${LATEST_VERSION}_HOME=/usr/lib/jvm/${LATEST_VERSION}

ENV JAVA_HOME=${JAVA_8_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}

FROM base AS variant
ARG VARIANT_LOWER
ARG VARIANT_UPPER

COPY --from=all-jdk /usr/lib/jvm/${VARIANT_LOWER} /usr/lib/jvm/${VARIANT_LOWER}
ENV JAVA_${VARIANT_UPPER}_HOME=/usr/lib/jvm/${VARIANT_LOWER}
ENV JAVA_${VARIANT_LOWER}_HOME=/usr/lib/jvm/${VARIANT_LOWER}

# Full image for debugging, contains all JDKs.
FROM base AS full

COPY --from=all-jdk /usr/lib/jvm/7 /usr/lib/jvm/7
COPY --from=all-jdk /usr/lib/jvm/zulu8 /usr/lib/jvm/zulu8
COPY --from=all-jdk /usr/lib/jvm/zulu11 /usr/lib/jvm/zulu11
COPY --from=all-jdk /usr/lib/jvm/oracle8 /usr/lib/jvm/oracle8
COPY --from=all-jdk /usr/lib/jvm/ibm8 /usr/lib/jvm/ibm8
COPY --from=all-jdk /usr/lib/jvm/semeru8 /usr/lib/jvm/semeru8
COPY --from=all-jdk /usr/lib/jvm/semeru11 /usr/lib/jvm/semeru11
COPY --from=all-jdk /usr/lib/jvm/semeru17 /usr/lib/jvm/semeru17
COPY --from=all-jdk /usr/lib/jvm/ubuntu17 /usr/lib/jvm/ubuntu17
COPY --from=all-jdk /usr/lib/jvm/graalvm17 /usr/lib/jvm/graalvm17
COPY --from=all-jdk /usr/lib/jvm/graalvm21 /usr/lib/jvm/graalvm21

ENV JAVA_7_HOME=/usr/lib/jvm/7

ENV JAVA_ZULU7_HOME=/usr/lib/jvm/7
ENV JAVA_ZULU8_HOME=/usr/lib/jvm/zulu8
ENV JAVA_ZULU11_HOME=/usr/lib/jvm/zulu11

ENV JAVA_ORACLE8_HOME=/usr/lib/jvm/oracle8

ENV JAVA_IBM8_HOME=/usr/lib/jvm/ibm8
# Temporarily set these aliases for backwards compatibility.
ENV JAVA_IBM11_HOME=/usr/lib/jvm/semeru11
ENV JAVA_IBM17_HOME=/usr/lib/jvm/semeru17

ENV JAVA_SEMERU8_HOME=/usr/lib/jvm/semeru8
ENV JAVA_SEMERU11_HOME=/usr/lib/jvm/semeru11
ENV JAVA_SEMERU17_HOME=/usr/lib/jvm/semeru17

ENV JAVA_UBUNTU17_HOME=/usr/lib/jvm/ubuntu17

ENV JAVA_GRAALVM17_HOME=/usr/lib/jvm/graalvm17
ENV JAVA_GRAALVM21_HOME=/usr/lib/jvm/graalvm21
