
FROM circleci/openjdk:11.0.7-buster

RUN sudo apt-get -y clean && sudo rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    sudo apt-get update; \
    sudo apt-get dist-upgrade; \
    sudo apt-get install apt-transport-https socat; \
    sudo apt-get install vim less debian-goodies; \
    sudo apt-get install openjdk-8-jdk

RUN set -eux; \
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xb1998361219bd9c9; \
    echo 'deb http://repos.azulsystems.com/debian stable main' | sudo tee -a /etc/apt/sources.list.d/zulu.list; \
    sudo apt-get update; \
    sudo apt-get install zulu-7 zulu-8 zulu-9 zulu-10 zulu-11 zulu-12 zulu-13 zulu-14;

RUN set -eux; \
    JAVA_VERSION=1.8.0_sr6fp6; \
    SUM='c1fd9c8ad1cf5e93dd6dfb70a04d41d33e6b554fda314841a6a9443b15317be8'; \
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

RUN sudo rm -rf /tmp/..?* /tmp/.[!.]* /tmp/*

RUN sudo apt-get -y clean && sudo rm -rf /var/lib/apt/lists/*

ENV JAVA_IBM8_HOME=/opt/ibm/java/jre \
    IBM_JAVA_OPTIONS="-XX:+UseContainerSupport"

#Set some odd looking variables, since their default values are wrong and it is unclear how they are used
ENV JAVA_DEBIAN_VERSION=unused
ENV JAVA_VERSION=unused

# Make java8 a default jvm
RUN sudo update-java-alternatives -s java-1.8.0-openjdk-amd64

ENV JAVA_7_HOME=/usr/lib/jvm/zulu-7-amd64
ENV JAVA_8_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV JAVA_9_HOME=/usr/lib/jvm/zulu-9-amd64
ENV JAVA_10_HOME=/usr/lib/jvm/zulu-10-amd64
ENV JAVA_11_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV JAVA_12_HOME=/usr/lib/jvm/zulu-12-amd64
ENV JAVA_13_HOME=/usr/lib/jvm/zulu-13-amd64
ENV JAVA_14_HOME=/usr/lib/jvm/zulu-14-amd64

ENV JAVA_ZULU8_HOME=/usr/lib/jvm/zulu-8-amd64
ENV JAVA_ZULU11_HOME=/usr/lib/jvm/zulu-11-amd64

ENV JAVA_HOME=${JAVA_8_HOME}
