
FROM circleci/openjdk:8

RUN set -eux; \
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x219BD9C9; \
    echo 'deb http://repos.azulsystems.com/debian stable main' | sudo tee -a /etc/apt/sources.list.d/zulu.list; \
    sudo apt-get update; \
    sudo apt-get dist-upgrade; \
    sudo apt-get install socat zulu-7 zulu-9 zulu-10 zulu-11 zulu-12;

ENV JAVA_7_HOME=/usr/lib/jvm/zulu-7-amd64
ENV JAVA_9_HOME=/usr/lib/jvm/zulu-9-amd64
ENV JAVA_10_HOME=/usr/lib/jvm/zulu-10-amd64
ENV JAVA_11_HOME=/usr/lib/jvm/zulu-11-amd64
ENV JAVA_12_HOME=/usr/lib/jvm/zulu-12-amd64

ENV JAVA_VERSION 1.8.0_sr5fp36

RUN set -eux; \
    JAVA_VERSION=1.8.0_sr5fp36; \
    SUM='548b35eb9677915df6819f9375567736de2ba6862e50ab1685a06becc943fa00'; \
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
