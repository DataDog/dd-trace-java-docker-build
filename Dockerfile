# GraalVM with native image support
FROM ghcr.io/graalvm/graalvm-ce:ol8-java11-22 AS graalvm-native-image-jdk11
RUN gu install native-image

FROM ghcr.io/graalvm/graalvm-ce:ol8-java17-22 AS graalvm-native-image-jdk17
RUN gu install native-image

# CircleCI Base Image with Ubuntu 22.04.3 LTS
FROM cimg/base:edge-22.04 AS builder

COPY --from=eclipse-temurin:8-jdk-jammy /opt/java/openjdk /usr/lib/jvm/openjdk8
COPY --from=eclipse-temurin:11-jdk-jammy /opt/java/openjdk /usr/lib/jvm/openjdk11
COPY --from=eclipse-temurin:17-jdk-jammy /opt/java/openjdk /usr/lib/jvm/openjdk17

COPY --from=azul/zulu-openjdk:7 /usr/lib/jvm/zulu7 /usr/lib/jvm/zulu7
COPY --from=azul/zulu-openjdk:8 /usr/lib/jvm/zulu8 /usr/lib/jvm/zulu8
COPY --from=azul/zulu-openjdk:11 /usr/lib/jvm/zulu11 /usr/lib/jvm/zulu11

COPY --from=ibmjava:8-sdk /opt/ibm/java /usr/lib/jvm/ibm8

COPY --from=ibm-semeru-runtimes:open-8-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru8
COPY --from=ibm-semeru-runtimes:open-11-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru11
COPY --from=ibm-semeru-runtimes:open-17-jdk-jammy /opt/java/openjdk /usr/lib/jvm/semeru17

COPY --from=graalvm-native-image-jdk11 /opt/graalvm-ce-java11-22* /usr/lib/jvm/graalvm22-jdk11
COPY --from=graalvm-native-image-jdk17 /opt/graalvm-ce-java17-22* /usr/lib/jvm/graalvm22-jdk17

RUN sudo apt-get -y update && sudo apt-get -y install curl
# See: https://gist.github.com/wavezhang/ba8425f24a968ec9b2a8619d7c2d86a6
RUN set -eux; \
    sudo mkdir -p /usr/lib/jvm/oracle8; \
    curl -L --fail "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=246284_165374ff4ea84ef0bbd821706e29b123" | sudo tar -xvzf - -C /usr/lib/jvm/oracle8 --strip-components 1

RUN sudo rm -rf \
    /usr/lib/jvm/*/man \
    /usr/lib/jvm/*/lib/src.zip \
    /usr/lib/jvm/*/demo \
    /usr/lib/jvm/*/sample \
    /usr/lib/jvm/graalvm*/lib/installer

FROM cimg/base:edge-22.04

COPY --from=builder /usr/lib/jvm /usr/lib/jvm

COPY autoforward.py /usr/local/bin/autoforward

RUN set -eux; \
    sudo apt-get update; \
    sudo apt-get install --no-install-recommends apt-transport-https socat; \
    sudo apt-get install --no-install-recommends vim less debian-goodies; \
    sudo apt-get install --no-install-recommends autossh; \
    sudo apt install python3-pip; \
    sudo apt-get -y clean; \
    sudo rm -rf /var/lib/apt/lists/*; \
    pip3 install awscli; \
    pip3 install requests requests-unixsocket; \
    pip3 cache purge; \
    sudo chmod +x /usr/local/bin/autoforward; \
    sudo curl -L --fail "https://github.com/DataDog/datadog-ci/releases/download/v1.3.0-alpha/datadog-ci_linux-x64" --output "/usr/local/bin/datadog-ci"; \
    sudo chmod +x /usr/local/bin/datadog-ci;\
    sudo rm -rf /tmp/..?* /tmp/.[!.]* /tmp/*;


# IBM specific env variables
ENV IBM_JAVA_OPTIONS="-XX:+UseContainerSupport"

#Set some odd looking variables, since their default values are wrong and it is unclear how they are used
ENV JAVA_DEBIAN_VERSION=unused
ENV JAVA_VERSION=unused

# Setup environment variables to point to all jvms we have
ENV JAVA_7_HOME=/usr/lib/jvm/zulu7
ENV JAVA_8_HOME=/usr/lib/jvm/openjdk8
ENV JAVA_11_HOME=/usr/lib/jvm/openjdk11
ENV JAVA_17_HOME=/usr/lib/jvm/openjdk17

ENV JAVA_ZULU7_HOME=/usr/lib/jvm/zulu7
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

ENV JAVA_GRAALVM11_HOME=/usr/lib/jvm/graalvm22-jdk11
ENV JAVA_GRAALVM17_HOME=/usr/lib/jvm/graalvm22-jdk17

ENV JAVA_HOME=${JAVA_8_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}
