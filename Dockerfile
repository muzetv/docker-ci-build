FROM ubuntu:18.04

ENV PYTHON_VERSION="3.8.0" \
 JAVA_VERSION=11 \
 NODE_12_VERSION="12.13.0" \
 NODE_10_VERSION="10.17.0" \
 DOCKER_VERSION="19.03.1" \
 DOCKER_COMPOSE_VERSION="1.24.0"


#****************        Utilities     *********************************************
ENV DOCKER_BUCKET="download.docker.com" \
    DOCKER_CHANNEL="stable" \
    DOCKER_SHA256="6e7d8e24ee46b13d7547d751696d01607d19c8224c1b2c867acc8c779e77734b" \
    DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \
    GITVERSION_VERSION="4.0.0" \
    DEBIAN_FRONTEND="noninteractive" \
    SRC_DIR="/usr/src"

# Install git, SSH, and other utilities
RUN set -ex \
    && echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression \
    && apt-get update \
    && apt install -y apt-transport-https gnupg ca-certificates \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
    && echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list \
    && apt-get update \
    && apt-get install software-properties-common -y --no-install-recommends \
    && apt-add-repository -y ppa:git-core/ppa \
    && apt-get update \
    && apt-get install git=1:2.* -y --no-install-recommends \
    && git version \
    && apt-get install -y --no-install-recommends openssh-client \
    && mkdir ~/.ssh \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && apt-get install -y --no-install-recommends \
       sudo wget python3 python3-dev python3-pip python3-setuptools fakeroot jq \
       netbase dirmngr bzr mercurial procps \
       tar gzip zip autoconf automake \
       bzip2 file g++ gcc imagemagick \
       libbz2-dev libc6-dev libcurl4-openssl-dev libdb-dev \
       libevent-dev libffi-dev libgeoip-dev libglib2.0-dev \
       libjpeg-dev libkrb5-dev liblzma-dev \
       libmagickcore-dev libmagickwand-dev libmysqlclient-dev \
       libncurses5-dev libpq-dev libreadline-dev \
       libsqlite3-dev libssl-dev libtool libwebp-dev \
       libxml2-dev libxslt1-dev libyaml-dev make \
       patch xz-utils zlib1g-dev unzip curl \
       e2fsprogs iptables xfsprogs \
       mono-devel less groff liberror-perl \
       asciidoc build-essential bzr cvs cvsps docbook-xml docbook-xsl dpkg-dev \
       libdbd-sqlite3-perl libdbi-perl libdpkg-perl libhttp-date-perl \
       libio-pty-perl libserf-1-1 libsvn-perl libsvn1 libtcl8.6 libtimedate-perl \
       libxml2-utils libyaml-perl python-bzrlib python-configobj \
       sgml-base sgml-data subversion tcl tcl8.6 xml-core xmlto xsltproc \
       tk gettext gettext-base libapr1 libaprutil1 xvfb expect parallel \
       locales rsync \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Download and set up GitVersion
RUN set -ex \
    && wget "https://github.com/GitTools/GitVersion/releases/download/v${GITVERSION_VERSION}/GitVersion-bin-net40-v${GITVERSION_VERSION}.zip" -O /tmp/GitVersion_${GITVERSION_VERSION}.zip \
    && mkdir -p /usr/local/GitVersion_${GITVERSION_VERSION} \
    && unzip /tmp/GitVersion_${GITVERSION_VERSION}.zip -d /usr/local/GitVersion_${GITVERSION_VERSION} \
    && rm /tmp/GitVersion_${GITVERSION_VERSION}.zip \
    && echo "mono /usr/local/GitVersion_${GITVERSION_VERSION}/GitVersion.exe \$@" >> /usr/local/bin/gitversion \
    && chmod +x /usr/local/bin/gitversion

# Install Docker
RUN set -ex \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
    && rm docker.tgz \
    && docker -v \
# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && addgroup dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
# Ensure docker-compose works
    && docker-compose version

# https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html
RUN curl -sS -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
    && curl -sS -o /usr/local/bin/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/kubectl \
    && curl -sS -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest \
    && chmod +x /usr/local/bin/kubectl /usr/local/bin/aws-iam-authenticator /usr/local/bin/ecs-cli

RUN set -ex \
    && pip3 install wheel

RUN set -ex \
    && pip3 install awscli boto3

VOLUME /var/lib/docker

# Configure SSH
COPY ssh_config /root/.ssh/config

#****************        PYTHON     *********************************************
ENV PATH="/usr/local/bin:$PATH" \
    GPG_KEY="E3FF2839C048B25C084DEBE9B26995E310250568" \
    PYTHON_PIP_VERSION="19.1.1" \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        tcl-dev tk-dev \
    && rm -rf /var/lib/apt/lists/* \
    && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" && \
    wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && (gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$GPG_KEY" \
        || gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$GPG_KEY" \
        || gpg --keyserver pgp.mit.edu --recv-keys "$GPG_KEY") \
    && gpg --batch --verify python.tar.xz.asc python.tar.xz \
    && rm -rf "$GNUPGHOME" python.tar.xz.asc \
    && mkdir -p /usr/src/python \
    && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
    && rm python.tar.xz \
    \
    && cd /usr/src/python \
    && ./configure \
        --enable-loadable-sqlite-extensions \
        --enable-shared \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
# explicit path to "pip3" to ensure distribution-provided "pip3" cannot interfere
    && if [ ! -e /usr/local/bin/pip3 ]; then : \
        && wget -O /tmp/get-pip.py 'https://bootstrap.pypa.io/get-pip.py' \
        && python3 /tmp/get-pip.py "pip==$PYTHON_PIP_VERSION" \
        && rm /tmp/get-pip.py \
    ; fi \
# we use "--force-reinstall" for the case where the version of pip we're trying to install is the same as the version bundled with Python
# ("Requirement already up-to-date: pip==8.1.2 in /usr/local/lib/python3.6/site-packages")
# https://github.com/docker-library/python/pull/143#issuecomment-241032683
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
        && pip install pipenv virtualenv --no-cache-dir \
        && pip3 install --no-cache-dir --upgrade setuptools wheel \
# then we use "pip list" to ensure we don't have more than one pip version installed
# https://github.com/docker-library/python/pull/100
    && [ "$(pip list |tac|tac| awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP_VERSION" ] \
    \
    && find /usr/local -depth \
        \( \
            \( -type d -a -name test -o -name tests \) \
            -o \
            \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
        \) -exec rm -rf '{}' + \
    && apt-get purge -y --auto-remove tcl-dev tk-dev \
    && rm -rf /usr/src/python ~/.cache \
    && cd /usr/local/bin \
    && { [ -e easy_install ] || ln -s easy_install-* easy_install; } \
    && ln -s idle3 idle \
    && ln -s pydoc3 pydoc \
    && ln -s python3 python \
    && ln -s python3-config python-config \
        && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*
#****************      END PYTHON     *********************************************


#****************      NODEJS     ****************************************************

 ENV N_SRC_DIR="$SRC_DIR/n"

 RUN git clone https://github.com/tj/n $N_SRC_DIR \
     && cd $N_SRC_DIR && make install \
     && n $NODE_10_VERSION && npm install --save-dev -g grunt && npm install --save-dev -g grunt-cli && npm install --save-dev -g webpack \
     && n $NODE_12_VERSION && npm install --save-dev -g grunt && npm install --save-dev -g grunt-cli && npm install --save-dev -g webpack \
     && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
     && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
     && apt-get update && apt-get install -y --no-install-recommends yarn \
     && cd / && rm -rf $N_SRC_DIR;

#****************      END NODEJS     ****************************************************

#****************      JAVA     ****************************************************
# Copy install tools
COPY tools /opt/tools

ENV JAVA_11_HOME="/opt/jvm/openjdk-11" \
    JDK_11_HOME="/opt/jvm/openjdk-11" \
    JRE_11_HOME="/opt/jvm/openjdk-11" \
    JAVA_8_HOME="/usr/lib/jvm/java-8-openjdk-amd64" \
    JDK_8_HOME="/usr/lib/jvm/java-8-openjdk-amd64" \
    JRE_8_HOME="/usr/lib/jvm/java-8-openjdk-amd64/jre" \
    ANT_VERSION=1.10.6 \
    MAVEN_HOME="/opt/maven" \
    MAVEN_VERSION=3.6.3 \
    MAVEN_CONFIG="/root/.m2" \
    INSTALLED_GRADLE_VERSIONS="6.0.1" \
    GRADLE_VERSION=6.0.1 \
    SBT_VERSION=1.2.8 \
    JDK_VERSION=11.0.2 \
    JDK_VERSION_TAG=9 \
    GRADLE_PATH="$SRC_DIR/gradle" \
    JDK_DOWNLOAD_SHA256="99be79935354f5c0df1ad293620ea36d13f48ec3ea870c838f20c504c9668b57" \
    ANT_DOWNLOAD_SHA512="c1a9694c3018e248000ff6f46d48af85f537ef3935e0d5256543c58a240084c0aff5289fd9e94cbc40d5442f3cc43592398047f2548fded40d9882be2b40750d" \
    MAVEN_DOWNLOAD_SHA512="c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0" \
    GRADLE_DOWNLOADS_SHA256="6f6cfdbb12a577c3845522a1c7fbfe1295ea05d87edabedd4e23fd2bf02b88b1 6.0.1"

ENV JDK_DOWNLOAD_TAR="openjdk-${JDK_VERSION}_linux-x64_bin.tar.gz" \
    JAVA_HOME="$JAVA_11_HOME" \
    JDK_HOME="$JDK_11_HOME" \
    JRE_HOME="$JRE_11_HOME"

ENV PATH="${PATH}:/opt/tools"

RUN set -ex \
    && apt-get update \
    && apt-get install -y software-properties-common \
    # Install OpenJDK 8
    && add-apt-repository -y ppa:openjdk-r/ppa \
    && apt-get update \
    && apt-get install -y openjdk-8-jdk \
    && apt-get install -y --no-install-recommends ca-certificates-java \
    # Ensure Java cacerts symlink points to valid location
    && update-ca-certificates -f \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --force-yes libc6-i386 \
       lib32stdc++6 lib32gcc1 lib32ncurses5 \
       lib32z1 libqt5widgets5 \
    && apt-get install -y python-setuptools \
    # Install OpenJDK 11
    # Note: We will use update-alternatives to make sure JDK11 has higher priority for all the tools
    && mkdir -p $JAVA_HOME \
    && curl -LSso /var/tmp/$JDK_DOWNLOAD_TAR https://download.java.net/java/GA/jdk$JAVA_VERSION/$JDK_VERSION_TAG/GPL/$JDK_DOWNLOAD_TAR \
    && echo "$JDK_DOWNLOAD_SHA256 /var/tmp/$JDK_DOWNLOAD_TAR" | sha256sum -c - \
    && tar xzvf /var/tmp/$JDK_DOWNLOAD_TAR -C $JAVA_HOME --strip-components=1 \
    && for tool_path in $JAVA_HOME/bin/*; do \
          tool=`basename $tool_path`; \
          update-alternatives --install /usr/bin/$tool $tool $tool_path 10000; \
          update-alternatives --set $tool $tool_path; \
        done \
     && rm $JAVA_HOME/lib/security/cacerts && ln -s /etc/ssl/certs/java/cacerts $JAVA_HOME/lib/security/cacerts \
    # Install Ant
    && curl -LSso /var/tmp/apache-ant-$ANT_VERSION-bin.tar.gz https://archive.apache.org/dist/ant/binaries/apache-ant-$ANT_VERSION-bin.tar.gz  \
    && echo "$ANT_DOWNLOAD_SHA512 /var/tmp/apache-ant-$ANT_VERSION-bin.tar.gz" | sha512sum -c - \
    && tar -xzf /var/tmp/apache-ant-$ANT_VERSION-bin.tar.gz -C /opt \
    && update-alternatives --install /usr/bin/ant ant /opt/apache-ant-$ANT_VERSION/bin/ant 10000 \
    # Install Maven
    && mkdir -p $MAVEN_HOME \
    && curl -LSso /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz https://apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    && echo "$MAVEN_DOWNLOAD_SHA512 /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz" | sha512sum -c - \
    && tar xzvf /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz -C $MAVEN_HOME --strip-components=1 \
    && update-alternatives --install /usr/bin/mvn mvn /opt/maven/bin/mvn 10000 \
    && mkdir -p $MAVEN_CONFIG \
    # Install Gradle
    && mkdir -p $GRADLE_PATH \
    && for version in $INSTALLED_GRADLE_VERSIONS; do { \
       wget "https://services.gradle.org/distributions/gradle-$version-all.zip" -O "$GRADLE_PATH/gradle-$version-all.zip" \
       && unzip "$GRADLE_PATH/gradle-$version-all.zip" -d /usr/local \
       && echo "$GRADLE_DOWNLOADS_SHA256" | grep "$version" | sed "s|$version|$GRADLE_PATH/gradle-$version-all.zip|" | sha256sum -c - \
       && mkdir "/tmp/gradle-$version" \
       && "/usr/local/gradle-$version/bin/gradle" -p "/tmp/gradle-$version" wrapper \
       # Android Studio uses the "-all" distribution for it's wrapper script.
       && perl -pi -e "s/gradle-$version-bin.zip/gradle-$version-all.zip/" "/tmp/gradle-$version/gradle/wrapper/gradle-wrapper.properties" \
       && "/tmp/gradle-$version/gradlew" -p "/tmp/gradle-$version" init \
       && rm -rf "/tmp/gradle-$version" \
       && if [ "$version" != "$GRADLE_VERSION" ]; then rm -rf "/usr/local/gradle-$version"; fi; \
     }; done \
    # Install default GRADLE_VERSION to path
      && ln -s /usr/local/gradle-$GRADLE_VERSION/bin/gradle /usr/bin/gradle \
      && rm -rf $GRADLE_PATH \
    # Install SBT
    && echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list \
    && apt-get install -y --no-install-recommends apt-transport-https \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823 \
    && apt-get update \
    && apt-get install -y --no-install-recommends sbt=$SBT_VERSION \
    # Cleanup
    && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get clean
#****************     END JAVA     ****************************************************

RUN set -ex \
   && apt-get install -y openssl \
   && curl -o stunnel-5.55.tar.gz https://www.stunnel.org/downloads/stunnel-5.55.tar.gz \
   && tar xvfz stunnel-5.55.tar.gz \
   && cd stunnel-5.55 \
   && ./configure \
   && make \
   && make install \
   && openssl genrsa -out key.pem 2048 \
   && openssl req -new -x509 -key key.pem -out cert.pem -days 1095 -subj "/C=US/ST=Washington/L=Seattle/O=Amazon/OU=Codebuild/CN=codebuild.amazon.com" \
   && cat key.pem cert.pem >> /usr/local/etc/stunnel/stunnel.pem \
   && cd .. ; rm -rf stunnel-5.55* \
   && apt-get clean

# Homebrew
RUN useradd -m -s /bin/bash muzetv \
	&& echo 'muzetv ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers
USER muzetv
WORKDIR /home/muzetv
ENV LANG=en_US.UTF-8 \
	PATH=/home/muzetv/.linuxbrew/bin:/home/muzetv/.linuxbrew/sbin:$PATH \
	SHELL=/bin/bash

RUN git clone https://github.com/Homebrew/brew /home/muzetv/.linuxbrew/Homebrew \
	&& mkdir /home/muzetv/.linuxbrew/bin \
	&& ln -s ../Homebrew/bin/brew /home/muzetv/.linuxbrew/bin/ \
	&& brew config \
	# Install aws sam cli
	&& brew tap aws/tap \
	&& brew install aws-sam-cli

ADD dockerd-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["dockerd-entrypoint.sh"]