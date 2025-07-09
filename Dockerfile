# syntax=docker/dockerfile:1.6

ARG LATEST_VERSION
FROM eclipse-temurin:${LATEST_VERSION}-jdk-noble AS temurin-latest

# Intermediate image used to prune cruft from JDKs and squash them all.
FROM ubuntu:24.04 AS all-jdk
ARG LATEST_VERSION

RUN <<-EOT
	set -eux
	apt-get update
	apt-get install -y sudo
	groupadd --gid 1001 non-root-group
	useradd --uid 1001 --gid non-root-group -m non-root-user
	echo "non-root-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/non-root-user
	chmod 0440 /etc/sudoers.d/non-root-user
	mkdir -p /home/non-root-user/.config
	chown -R non-root-user:non-root-group /home/non-root-user/.config
	apt-get clean
	rm -rf /var/lib/apt/lists/*
EOT

USER non-root-user
WORKDIR /home/non-root-user

RUN <<-EOT
	set -eux
	sudo apt-get update
	sudo apt-get install -y curl tar apt-transport-https ca-certificates gnupg locales jq git gh yq lsb-release lsof
	sudo locale-gen en_US.UTF-8
	sudo git config --system --add safe.directory "*"
	
	sudo mkdir -p /tmp/docker-install
	DOCKER_LATEST_VERSION=$(curl -s https://download.docker.com/linux/static/stable/$(uname -m)/ | grep -oP 'docker-\K([0-9]+\.[0-9]+\.[0-9]+)(?=\.tgz)' | sort -V | tail -n 1)
	sudo curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m)/docker-${DOCKER_LATEST_VERSION}.tgz" | sudo tar -xz -C /tmp/docker-install
	sudo mv /tmp/docker-install/docker/docker /usr/local/bin/
	sudo rm -rf /tmp/docker-install
	sudo mkdir -p /usr/local/lib/docker/cli-plugins
	sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
	sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
	
	sudo apt-get clean
	sudo rm -rf /var/lib/apt/lists/*
EOT

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

COPY --from=eclipse-temurin:8-jdk-jammy /opt/java/openjdk /usr/lib/jvm/8
COPY --from=eclipse-temurin:11-jdk-jammy /opt/java/openjdk /usr/lib/jvm/11
COPY --from=eclipse-temurin:17-jdk-jammy /opt/java/openjdk /usr/lib/jvm/17
COPY --from=eclipse-temurin:21-jdk-jammy /opt/java/openjdk /usr/lib/jvm/21
COPY --from=temurin-latest /opt/java/openjdk /usr/lib/jvm/${LATEST_VERSION}
# TODO: Update to eclipse-temurin:25-jdk-noble once JDK 25 is generally available (ETA Sep 16).
COPY --from=openjdk:25-jdk-bookworm /usr/local/openjdk-25 /usr/lib/jvm/25

COPY --from=azul/zulu-openjdk:7 /usr/lib/jvm/zulu7 /usr/lib/jvm/7
COPY --from=azul/zulu-openjdk:8 /usr/lib/jvm/zulu8 /usr/lib/jvm/zulu8
COPY --from=azul/zulu-openjdk:11 /usr/lib/jvm/zulu11 /usr/lib/jvm/zulu11

COPY --from=ibmjava:8-sdk /opt/ibm/java /usr/lib/jvm/ibm8

COPY --from=ibm-semeru-runtimes:open-8-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru8
COPY --from=ibm-semeru-runtimes:open-11-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru11
COPY --from=ibm-semeru-runtimes:open-17-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru17

COPY --from=ghcr.io/graalvm/native-image-community:17-ol9 /usr/lib64/graalvm/graalvm-community-java17 /usr/lib/jvm/graalvm17
COPY --from=ghcr.io/graalvm/native-image-community:21-ol9 /usr/lib64/graalvm/graalvm-community-java21 /usr/lib/jvm/graalvm21

# See: https://gist.github.com/wavezhang/ba8425f24a968ec9b2a8619d7c2d86a6
# Note it seems that latest Oracle JDK 8 are not available for download without an account.
# Latest available is jdk-8u381-linux-x64.tar.gz
RUN <<-EOT
	set -eux
	sudo mkdir -p /usr/lib/jvm/oracle8
	sudo curl -L --fail "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=248746_8c876547113c4e4aab3c868e9e0ec572" | sudo tar -xvzf - -C /usr/lib/jvm/oracle8 --strip-components 1
EOT

# Remove cruft from JDKs that is not used in the build process.
RUN <<-EOT
	sudo rm -rf \
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
COPY --from=all-jdk /usr/lib/jvm/25 /usr/lib/jvm/25

# Base image with minimum requirements to build the project.
# Based on the latest Ubuntu LTS image.
FROM ubuntu:24.04 AS base
ARG LATEST_VERSION
ENV LATEST_VERSION=${LATEST_VERSION}

# https://docs.github.com/en/packages/learn-github-packages/connecting-a-repository-to-a-package
LABEL org.opencontainers.image.source=https://github.com/DataDog/dd-trace-java-docker-build

RUN <<-EOT
	set -eux
	apt-get update
	apt-get install -y sudo
	groupadd --gid 1001 non-root-group
	useradd --uid 1001 --gid non-root-group -m non-root-user
	echo "non-root-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/non-root-user
	chmod 0440 /etc/sudoers.d/non-root-user
	mkdir -p /home/non-root-user/.config
	chown -R non-root-user:non-root-group /home/non-root-user/.config
	apt-get clean
	rm -rf /var/lib/apt/lists/*
EOT

USER non-root-user
WORKDIR /home/non-root-user

RUN <<-EOT
	set -eux
	sudo apt-get update
	sudo apt-get install -y curl tar apt-transport-https ca-certificates gnupg socat less debian-goodies autossh ca-certificates-java python3-pip locales jq git gh yq lsb-release lsof
	sudo locale-gen en_US.UTF-8
	sudo git config --system --add safe.directory "*"
	
	sudo mkdir -p /tmp/docker-install
	DOCKER_LATEST_VERSION=$(curl -s https://download.docker.com/linux/static/stable/$(uname -m)/ | grep -oP 'docker-\K([0-9]+\.[0-9]+\.[0-9]+)(?=\.tgz)' | sort -V | tail -n 1)
	sudo curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m)/docker-${DOCKER_LATEST_VERSION}.tgz" | sudo tar -xz -C /tmp/docker-install
	sudo mv /tmp/docker-install/docker/docker /usr/local/bin/
	sudo rm -rf /tmp/docker-install
	sudo mkdir -p /usr/local/lib/docker/cli-plugins
	sudo curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
	sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
	
	sudo apt-get clean
	sudo rm -rf /var/lib/apt/lists/*
EOT

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

COPY --from=default-jdk /usr/lib/jvm /usr/lib/jvm

# Install the following tools
# - awscli: AWS CLI
# - datadog-ci: Datadog CI tool
RUN <<-EOT
	set -eux
	sudo apt-get update
	sudo pip3 install --break-system-packages awscli
	sudo pip3 cache purge
	sudo curl -L --fail "https://github.com/DataDog/datadog-ci/releases/latest/download/datadog-ci_linux-x64" --output "/usr/local/bin/datadog-ci"
	sudo chmod +x /usr/local/bin/datadog-ci
	sudo apt-get clean
	sudo rm -rf /var/lib/apt/lists/*
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
ENV JAVA_25_HOME=/usr/lib/jvm/25

ENV JAVA_HOME=${JAVA_8_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}

FROM base AS variant
ARG VARIANT_LOWER
ARG VARIANT_UPPER

USER non-root-user
WORKDIR /home/non-root-user

COPY --from=all-jdk /usr/lib/jvm/${VARIANT_LOWER} /usr/lib/jvm/${VARIANT_LOWER}
ENV JAVA_${VARIANT_UPPER}_HOME=/usr/lib/jvm/${VARIANT_LOWER}
ENV JAVA_${VARIANT_LOWER}_HOME=/usr/lib/jvm/${VARIANT_LOWER}

# Full image for debugging, contains all JDKs.
FROM base AS full

USER non-root-user
WORKDIR /home/non-root-user

COPY --from=all-jdk /usr/lib/jvm/7 /usr/lib/jvm/7
COPY --from=all-jdk /usr/lib/jvm/zulu8 /usr/lib/jvm/zulu8
COPY --from=all-jdk /usr/lib/jvm/zulu11 /usr/lib/jvm/zulu11
COPY --from=all-jdk /usr/lib/jvm/oracle8 /usr/lib/jvm/oracle8
COPY --from=all-jdk /usr/lib/jvm/ibm8 /usr/lib/jvm/ibm8
COPY --from=all-jdk /usr/lib/jvm/semeru8 /usr/lib/jvm/semeru8
COPY --from=all-jdk /usr/lib/jvm/semeru11 /usr/lib/jvm/semeru11
COPY --from=all-jdk /usr/lib/jvm/semeru17 /usr/lib/jvm/semeru17
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

ENV JAVA_GRAALVM17_HOME=/usr/lib/jvm/graalvm17
ENV JAVA_GRAALVM21_HOME=/usr/lib/jvm/graalvm21
