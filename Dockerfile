FROM tomcat:8.5-jre8-slim

LABEL mantainer="Ángel Iglesias <angelo.fly1@gmail.com>"

#PREPARES ENVIRONMENT AND TOMCAT
ENV GEOSERVER_BRANCH=2.12 \
    ANT_VERSION=1.10.2 \
    GDAL_VERSION=2.2.3 \
    GEOSERVER_DATA_DIR=/var/local/geoserver \
    GEOSERVER_INSTALL_DIR=/usr/local/geoserver \
    WEBAPPS_DIR=/usr/local/tomcat/webapps \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    JAVA_OPTS=-Xbootclasspath/a:${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/marlin-0.7.5-Unsafe.jar -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine \
    GDAL_DATA=/var/local/gdal-data
ENV ANT_HOME=/usr/local/apache-ant-${ANT_VERSION} \
    LD_LIBRARY_PATH=/opt/jni:${LD_LIBRARY_PATH}
ENV PATH=${ANT_HOME}/bin:${JAVA_HOME}/bin:$PATH

RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install openjdk-8-jdk="$JAVA_DEBIAN_VERSION" &&\
    apt-get -y install wget
#GEOSERVER PREPARATIONS
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

#Geoserver installation
COPY config/server.xml /usr/local/tomcat/conf/server.xml
COPY config/geoserver.xml /usr/local/tomcat/conf/Catalina/localhost/geoserver.xml
RUN mkdir ${GEOSERVER_DATA_DIR} \
    && mkdir ${GEOSERVER_INSTALL_DIR} \
    && cd ${GEOSERVER_INSTALL_DIR} \
    && wget https://build.geoserver.org/geoserver/${GEOSERVER_BRANCH}.x/geoserver-${GEOSERVER_BRANCH}.x-latest-war.zip \
    && unzip geoserver-${GEOSERVER_BRANCH}.x-latest-war.zip \
    && unzip geoserver.war \
    && mv data/* ${GEOSERVER_DATA_DIR} \
    && rm -rf geoserver-${GEOSERVER_BRANCH}.x-latest-war.zip geoserver.war target *.txt

#PRERREQUISITES
##Apache Ant
RUN wget http://www-eu.apache.org/dist//ant/binaries/apache-ant-${ANT_VERSION}-bin.zip && \
    unzip apache-ant-${ANT_VERSION}-bin.zip && \
    mv apache-ant-${ANT_VERSION} /usr/local && \
    rm -rf apache-ant-${ANT_VERSION}-bin.zip

## Download gdal compilation
RUN wget http://download.osgeo.org/gdal/2.2.3/gdal-${GDAL_VERSION}.tar.gz && \
    tar -zxvf gdal-${GDAL_VERSION}.tar.gz && \
    rm -rf gdal-${GDAL_VERSION}.tar.gz

##libgdal and gdal compilation
COPY resources/libecwj2-3.3-patched ./libecwj2-3.3-patched
RUN apt-get -y install build-essential swig && \
    cd libecwj2-3.3-patched && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    make clean && \
    cd ../gdal-${GDAL_VERSION} && \
    ldconfig &&\
    ./configure --with-ecw=/usr/local --with-java=$JAVA_HOME && \
    make -j$(nproc) && \
    make install && \
    cd swig/java && \
    make -j$(nproc) && \
    mkdir /opt/jni && \
    cp *.so /opt/jni && \
    cp gdal.jar ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/ && \
    make clean && \
    cd ../.. && \
    make clean && \
    apt-get -y autoremove build-essential openjdk-8-jdk swig

# ##gdal data
COPY resources/gdal-data /var/local

#Installs any plugin zip files resources/plugins
COPY plugins ./plugins
RUN if ls -d /tmp/plugins/ > /dev/null 2>&1; then \
    cp -n /tmp/plugins/*.jar ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/ \
    && rm -rf /tmp/plugins; \
    fi;

#Installs any extra extension
##Prepares txt file substituing placceholders
COPY extensions.txt ./
RUN sed -i "s/\${branch}/${GEOSERVER_BRANCH}/g" extensions.txt &&\
    while read p; do \
    wget $p; \
    done < /tmp/extensions.txt
RUN for p in ./*.zip ; do \
    unzip $p && cp -n *.jar ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib && rm -rf *.jar && rm $p; \
    done

# Remove old gdal binding
RUN rm ${GEOSERVER_INSTALL_DIR}/WEB-INF/lib/imageio-ext-gdal-bindings-1.9.2.jar

WORKDIR $CATALINA_HOME/bin
EXPOSE 8082
CMD [ "catalina.sh", "run" ]
