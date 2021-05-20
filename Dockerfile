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
    ZULU_REPO_DEB=https://cdn.azul.com/zulu/bin/zulu-repo_1.0.0-2_all.deb; \
    SUM='b8d11979d9b1959b5ff621f1021ff0dba40c7d47d948ae6ec4a4bbde98cf71f5'; \
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xb1998361219bd9c9; \
    wget -q -O /tmp/zulu-repo.deb ${ZULU_REPO_DEB}; \
    echo "${SUM} /tmp/zulu-repo.deb" | sha256sum -c -; \
    sudo dpkg -i /tmp/zulu-repo.deb; \
    sudo apt-get update; \
    sudo apt-get install zulu7 zulu8 zulu11 zulu13 zulu15;

# Install oracle jvm
# Oracle is periodically removing older versions from the downloads - when that happens one needs to go to 
# https://www.oracle.com/java/technologies/javase/javase-jdk8-downloads.html to figure out the correct new link.
# !IMPORTANT! Replace '/otn/' with '/otn-pub/' to work around Oracle login issue
# See: https://gist.github.com/wavezhang/ba8425f24a968ec9b2a8619d7c2d86a6
RUN set -eux; \
    wget -q -O /tmp/oracle-jdk8.tar.gz -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "https://download.oracle.com/otn-pub/java/jdk/8u291-b10/d7fc238d0cbf4b0dac67be84580cfb4b/jdk-8u291-linux-x64.tar.gz"; \
    sudo tar xzf /tmp/oracle-jdk8.tar.gz -C /usr/lib/jvm/; \
    sudo mv /usr/lib/jvm/jdk1.8.0_281 /usr/lib/jvm/oracle8;

RUN set -eux; \
    JAVA_VERSION=1.8.0_sr6fp30; \
    SUM='afd31dea9c65fdfef664ac93140115f7c0746445bbe24fc7c62891236d28689d'; \
    YML_FILE='sdk/linux/x86_64/index.yml'; \
    BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta"; \ 
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
ENV JAVA_7_HOME=/usr/lib/jvm/zulu7
ENV JAVA_8_HOME=/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64
ENV JAVA_11_HOME=/usr/local/openjdk-11
ENV JAVA_13_HOME=/usr/lib/jvm/adoptopenjdk-13-hotspot-amd64
ENV JAVA_14_HOME=/usr/lib/jvm/adoptopenjdk-14-hotspot-amd64
ENV JAVA_15_HOME=/usr/lib/jvm/adoptopenjdk-15-hotspot-amd64

ENV JAVA_ZULU8_HOME=/usr/lib/jvm/zulu8
ENV JAVA_ZULU11_HOME=/usr/lib/jvm/zulu11
ENV JAVA_ZULU13_HOME=/usr/lib/jvm/zulu13
ENV JAVA_ZULU15_HOME=/usr/lib/jvm/zulu15

ENV JAVA_ORACLE8_HOME=/usr/lib/jvm/oracle8

ENV JAVA_HOME=${JAVA_8_HOME}
