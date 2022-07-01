# Build from circleci image that uses current debian
FROM cimg/base:edge-20.04 AS oracle8

RUN sudo apt-get -y update && sudo apt-get -y install curl

# See: https://gist.github.com/wavezhang/ba8425f24a968ec9b2a8619d7c2d86a6
RUN set -eux; \
    sudo mkdir -p /usr/lib/jvm/oracle8; \
    curl -L --fail "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=246242_165374ff4ea84ef0bbd821706e29b123" | sudo tar -xvzf - -C /usr/lib/jvm/oracle8 --strip-components 1

# CircleCI Base Image with Ubuntu 20.04.3 LTS
FROM cimg/base:edge-20.04

RUN sudo apt-get -y clean && sudo rm -rf /var/lib/apt/lists/*

# Install some common useful things
RUN set -eux; \
    sudo apt-get update; \
    sudo apt-get dist-upgrade; \
    sudo apt-get install apt-transport-https socat; \
    sudo apt-get install vim less debian-goodies;

COPY --from=openjdk:8-jdk-buster /usr/local/openjdk-8 /usr/lib/jvm/openjdk8
COPY --from=openjdk:11-jdk-buster /usr/local/openjdk-11 /usr/lib/jvm/openjdk11
COPY --from=openjdk:13-jdk-buster /usr/java/openjdk-13 /usr/lib/jvm/openjdk13
COPY --from=openjdk:14-jdk-buster /usr/local/openjdk-14 /usr/lib/jvm/openjdk14
COPY --from=openjdk:15-jdk-buster /usr/local/openjdk-15 /usr/lib/jvm/openjdk15
COPY --from=openjdk:16-jdk-buster /usr/local/openjdk-16 /usr/lib/jvm/openjdk16
COPY --from=openjdk:17-jdk-buster /usr/local/openjdk-17 /usr/lib/jvm/openjdk17
COPY --from=openjdk:18-jdk-buster /usr/local/openjdk-18 /usr/lib/jvm/openjdk18
COPY --from=openjdk:19-jdk-buster /usr/local/openjdk-19 /usr/lib/jvm/openjdk19

COPY --from=azul/zulu-openjdk-debian:7 /usr/lib/jvm/zulu7 /usr/lib/jvm/zulu7
COPY --from=azul/zulu-openjdk-debian:8 /usr/lib/jvm/zulu8 /usr/lib/jvm/zulu8
COPY --from=azul/zulu-openjdk-debian:11 /usr/lib/jvm/zulu11 /usr/lib/jvm/zulu11
COPY --from=azul/zulu-openjdk-debian:13 /usr/lib/jvm/zulu13 /usr/lib/jvm/zulu13
COPY --from=azul/zulu-openjdk-debian:15 /usr/lib/jvm/zulu15 /usr/lib/jvm/zulu15

COPY --from=ibm-semeru-runtimes:open-8-jdk-focal /opt/java/openjdk /usr/lib/jvm/ibm8
COPY --from=ibm-semeru-runtimes:open-11-jdk-focal /opt/java/openjdk /usr/lib/jvm/ibm11
COPY --from=ibm-semeru-runtimes:open-17-jdk-focal /opt/java/openjdk /usr/lib/jvm/ibm17

COPY --from=oracle8 /usr/lib/jvm/oracle8 /usr/lib/jvm/oracle8

# Install aws cli
RUN set -eux; \
    sudo apt install python3-pip; \
    pip3 install awscli;

# Install datadog-ci
RUN sudo curl -L --fail "https://github.com/DataDog/datadog-ci/releases/download/v1.3.0-alpha/datadog-ci_linux-x64" --output "/usr/local/bin/datadog-ci" \
    && sudo chmod +x /usr/local/bin/datadog-ci

RUN sudo rm -rf /tmp/..?* /tmp/.[!.]* /tmp/*

RUN sudo apt-get -y clean && sudo rm -rf /var/lib/apt/lists/*

# IBM specific env variables
ENV IBM_JAVA_OPTIONS="-XX:+UseContainerSupport"

#Set some odd looking variables, since their default values are wrong and it is unclear how they are used
ENV JAVA_DEBIAN_VERSION=unused
ENV JAVA_VERSION=unused

# Setup environment variables to point to all jvms we have
ENV JAVA_7_HOME=/usr/lib/jvm/zulu7
ENV JAVA_8_HOME=/usr/lib/jvm/openjdk8
ENV JAVA_11_HOME=/usr/lib/jvm/openjdk11
ENV JAVA_13_HOME=/usr/lib/jvm/openjdk13
ENV JAVA_14_HOME=/usr/lib/jvm/openjdk14
ENV JAVA_15_HOME=/usr/lib/jvm/openjdk15
ENV JAVA_16_HOME=/usr/lib/jvm/openjdk16
ENV JAVA_17_HOME=/usr/lib/jvm/openjdk17

ENV JAVA_ZULU8_HOME=/usr/lib/jvm/zulu8
ENV JAVA_ZULU11_HOME=/usr/lib/jvm/zulu11
ENV JAVA_ZULU13_HOME=/usr/lib/jvm/zulu13
ENV JAVA_ZULU15_HOME=/usr/lib/jvm/zulu15

ENV JAVA_ORACLE8_HOME=/usr/lib/jvm/oracle8

ENV JAVA_IBM8_HOME=/usr/lib/jvm/ibm8
ENV JAVA_IBM11_HOME=/usr/lib/jvm/ibm11
ENV JAVA_IBM17_HOME=/usr/lib/jvm/ibm17

ENV JAVA_HOME=${JAVA_8_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}
