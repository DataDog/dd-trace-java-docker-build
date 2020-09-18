# Build from circleci image that uses current debian
FROM circleci/openjdk:11.0.8-buster

RUN sudo apt-get -y clean && sudo rm -rf /var/lib/apt/lists/*

# Install some common useful things
RUN set -eux; \
    sudo apt-get update; \
    sudo apt-get dist-upgrade; \
    sudo apt-get install apt-transport-https socat; \
    sudo apt-get install vim less debian-goodies;

# Buster doesn't ship java8 so use one from adoptopenjdk
RUN set -eux; \
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x8ac3b29174885c03; \
    . /etc/os-release; \
    echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ $VERSION_CODENAME main" | sudo tee -a /etc/apt/sources.list.d/adoptopenjdk.list; \
    sudo apt-get update; \
    sudo apt-get install adoptopenjdk-8-hotspot adoptopenjdk-13-hotspot adoptopenjdk-14-hotspot adoptopenjdk-15-hotspot;

# Install zulu jvms
RUN set -eux; \
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xb1998361219bd9c9; \
    echo 'deb http://repos.azulsystems.com/debian stable main' | sudo tee -a /etc/apt/sources.list.d/zulu.list; \
    sudo apt-get update; \
    sudo apt-get install zulu-7 zulu-8 zulu-11 zulu-12 zulu-13 zulu-14;

RUN set -eux; \
    JAVA_VERSION=1.8.0_sr6fp10; \
    SUM='1a330b630b173fcecaeb730494612c1a28f7b73ea6a9b7eb41f29a9136ef3863'; \
    YML_FILE='sdk/linux/x86_64/index.yml'; \
    BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta/"; \
    wget -q -O /tmp/index.yml ${BASE_URL}/${YML_FILE}; \
    JAVA_URL=$(sed -n '/^'${JAVA_VERSION}:'/{n;s/\s*uri:\s//p}'< /tmp/index.yml); \
    wget -q -O /tmp/ibm-java.bin ${JAVA_URL}; \
    echo "${SUM}  /tmp/ibm-java.bin" | sha256sum -c -; \
    echo "INSTALLER_UI=silent" > /tmp/response.properties; \
    echo "USER_INSTALL_DIR=/opt/ibm/java" >> /tmp/response.properties; \
    echo "LICENSE_ACCEPTED=TRUE" >> /tmp/response.properties; \
    chmod +x /tmp/ibm-java.bin; \
    sudo mkdir -p /opt/ibm; \
    sudo /tmp/ibm-java.bin -i silent -f /tmp/response.properties; \
    rm -f /tmp/response.properties; \
    rm -f /tmp/index.yml; \
	rm -f /tmp/ibm-java.bin;

# Install aws cli
RUN set -eux; \
    sudo apt install python3-pip; \
    pip3 install awscli;

RUN sudo rm -rf /tmp/..?* /tmp/.[!.]* /tmp/*

RUN sudo apt-get -y clean && sudo rm -rf /var/lib/apt/lists/*

ENV JAVA_IBM8_HOME=/opt/ibm/java/jre \
    IBM_JAVA_OPTIONS="-XX:+UseContainerSupport"

#Set some odd looking variables, since their default values are wrong and it is unclear how they are used
ENV JAVA_DEBIAN_VERSION=unused
ENV JAVA_VERSION=unused

# Make java8 a default jvm
RUN sudo update-java-alternatives -s adoptopenjdk-8-hotspot-amd64

# Setup environment variables to point to all jvms we have
ENV JAVA_7_HOME=/usr/lib/jvm/zulu-7-amd64
ENV JAVA_8_HOME=/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64
ENV JAVA_11_HOME=/usr/local/openjdk-11
ENV JAVA_12_HOME=/usr/lib/jvm/zulu-12-amd64
ENV JAVA_13_HOME=/usr/lib/jvm/adoptopenjdk-13-hotspot-amd64
ENV JAVA_14_HOME=/usr/lib/jvm/adoptopenjdk-14-hotspot-amd64
ENV JAVA_15_HOME=/usr/lib/jvm/adoptopenjdk-15-hotspot-amd64

ENV JAVA_ZULU8_HOME=/usr/lib/jvm/zulu-8-amd64
ENV JAVA_ZULU11_HOME=/usr/lib/jvm/zulu-11-amd64
ENV JAVA_ZULU13_HOME=/usr/lib/jvm/zulu-13-amd64
ENV JAVA_ZULU14_HOME=/usr/lib/jvm/zulu-14-amd64

ENV JAVA_HOME=${JAVA_8_HOME}
