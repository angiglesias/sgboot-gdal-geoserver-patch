FROM ubuntu:latest
COPY sgboot-geoserver /opt/sgboot-geoserver
#PREPARES ENVIRONMENT AND TOMCAT
RUN apt-get update && apt-get upgrade -y \
    && echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" > /etc/apt/sources.list.d/webupd8team-java.list \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get update \
    && apt-get install -y build-essential \
    && apt-get install -y gdal-bin libgdal-java \
    && apt-get remove -y gdal-bin libgdal-java \
    && apt-get install -y --no-install-recommends ca-certificates \
    && echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections \
    && echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections \
    && apt-get install -y oracle-java8-installer \
    && apt-get install -y libapr1-dev libssl-dev \
    && wget https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.27/bin/apache-tomcat-8.5.27.tar.gz \
    && tar -zxvf apache-tomcat-8.5.27.tar.gz && mv apache-tomcat-8.5.27 /opt/ && rm apache-tomcat-8.5.27.tar.gz \
    && wget https://archive.apache.org/dist/tomcat/tomcat-connectors/native/1.2.16/source/tomcat-native-1.2.16-src.tar.gz \
    && tar -zxvf tomcat-native-1.2.16-src.tar.gz && rm tomcat-native-1.2.16-src.tar.gz \
    && cd tomcat-native-1.2.16-src/native && ./configure --with-apr=/usr/bin/apr-1-config \
    --with-java-home=/usr/lib/jvm/java-8-oracle \
    --with-ssl=yes \
    --prefix=/opt/apache-tomcat-8.5.27 \
    && make && make install

ENV JAVA_HOME=/usr/lib/jvm/java-8-oracle \
    LD_LIBRARY_PATH=/opt/jni:/opt/apache-tomcat-8.5.27/lib:$LD_LIBRARY_PATH \
    ANT_HOME=/opt/sgboot-geoserver/apache-ant-1.10.1 \
    GDAL_DATA=/opt/sgboot-geoserver/gdal-data
ENV PATH=$ANT_HOME/bin:$JAVA_HOME/bin:$PATH
#GEOSERVER PREPARATIONS
ENV GEOSERVER_VERSION=2.12.2 \
    GEOSERVER_DATA_DIR=/var/local/geoserver \
    GEOSERVER_INSTALL_DIR=/usr/local/geoserver \
    WEBAPPS_DIR=/opt/apache-tomcat-8.5.27/webapps
WORKDIR /tmp
RUN if [ ! -f /tmp/resources/jai-1_1_3-lib-linux-amd64.tar.gz ]; then \
    wget http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64.tar.gz -P ./resources;\
    fi; \
    if [ ! -f /tmp/resources/jai_imageio-1_1-lib-linux-amd64.tar.gz ]; then \
    wget http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64.tar.gz -P ./resources;\
    fi; \
    mv resources/jai-1_1_3-lib-linux-amd64.tar.gz ./ && \
    mv resources/jai_imageio-1_1-lib-linux-amd64.tar.gz ./ && \
    gunzip -c jai-1_1_3-lib-linux-amd64.tar.gz | tar xf - && \
    gunzip -c jai_imageio-1_1-lib-linux-amd64.tar.gz | tar xf - && \
    mv /tmp/jai-1_1_3/lib/*.jar $JAVA_HOME/jre/lib/ext/ && \
    mv /tmp/jai-1_1_3/lib/*.so $JAVA_HOME/jre/lib/amd64/ && \
    mv /tmp/jai_imageio-1_1/lib/*.jar $JAVA_HOME/jre/lib/ext/ && \
    mv /tmp/jai_imageio-1_1/lib/*.so $JAVA_HOME/jre/lib/amd64/ && \
    rm /tmp/jai-1_1_3-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai-1_1_3 && \
    rm /tmp/jai_imageio-1_1-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai_imageio-1_1
WORKDIR /opt/sgboot-geoserver
# RUN cp geoserver.war /opt/apache-tomcat-8.5.27/webapps/ \
#     && /bin/sh -c "/opt/apache-tomcat-8.5.27/bin/catalina.sh run &" \
#     && sleep 30 \
#     && /bin/sh -c "/opt/apache-tomcat-8.5.27/bin/catalina.sh stop"
#Checks if Tomcat and APR work OK
RUN set -e \
	&& nativeLines="$(/opt/apache-tomcat-8.5.27/bin/catalina.sh configtest 2>&1)" \
	&& nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
	&& nativeLines="$(echo "$nativeLines" | sort -u)" \
	&& if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then \
		echo >&2 "$nativeLines"; \
		exit 1; \
    fi
COPY conf/geoserver.xml /opt/apache-tomcat-8.5.27/conf/Catalina/localhost/
RUN mkdir ${GEOSERVER_DATA_DIR} \
    && mkdir ${GEOSERVER_INSTALL_DIR} \
    && cd ${GEOSERVER_INSTALL_DIR} \
    && wget http://sourceforge.net/projects/geoserver/files/GeoServer/${GEOSERVER_VERSION}/geoserver-${GEOSERVER_VERSION}-war.zip \
    && apt-get update && apt-get install -y unzip \
    && unzip geoserver-${GEOSERVER_VERSION}-war.zip \
    && unzip geoserver.war \
    && mv data/* ${GEOSERVER_DATA_DIR} \
    && rm -rf geoserver-${GEOSERVER_VERSION}-war.zip geoserver.war target *.txt
RUN cd libecwj2-3.3-patched \
    && ./configure \
    && make \
    && make install \
    && make clean \
    && cd ../gdal-1.11.3 \
    && ldconfig \
    && ./configure --with-ecw=/usr/local --with-java=$JAVA_HOME \
    && make \
    && make install \
    && cd swig/java \
    && make \
    && mkdir /opt/jni \
    && cp *.so /opt/jni \
    && make clean \
    && cd ../.. \
    && make clean
RUN cp geoserver-gdal-ext/*.jar ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/ \
    && cp gdal-1.11.3/swig/java/gdal.jar  ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/ \
    && cp geotools-18.2/gt-mongodb*.jar  ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/ \
    && cp geotools-18.2/mongo-java-driver*.jar  ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/ \
    && cp geotools-18.2/gt-app-schema*.jar  ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/
# ENV GEOSERVER_DATA_DIR=/usr/local/geoserver
# RUN mkdir ${GEOSERVER_DATA_DIR} \
#     && mv /opt/apache-tomcat-8.5.27/webapps/geoserver/data/* ${GEOSERVER_DATA_DIR}
EXPOSE 8080
CMD [ "/opt/apache-tomcat-8.5.27/bin/catalina.sh", "run" ]
