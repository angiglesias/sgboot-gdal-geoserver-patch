FROM  ibmjava:8-sdk
WORKDIR /usr/src/app
COPY sgboot-geoserver ./sgboot-geoserver
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y build-essential \
    && apt-get install -y gdal-bin libgdal-java \
    && apt-get remove -y gdal-bin libgdal-java
ENV JAVA_HOME=/opt/ibm/java \
    LD_LIBRARY_PATH=/opt/jni:$LD_LIBRARY_PATH \
    ANT_HOME=/usr/src/app/sgboot-geoserver/apache-ant-1.10.1 \
    GDAL_DATA=/usr/src/app/sgboot-geoserver/gdal-data
ENV PATH=$ANT_HOME/bin:$PATH
WORKDIR /usr/src/app/sgboot-geoserver
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
RUN cp geoserver-2.12.1-gdal/*.jar geoserver-2.12.1/webapps/geoserver/WEB-INF/lib/ \
    && cp gdal-1.11.3/swig/java/gdal.jar geoserver-2.12.1/webapps/geoserver/WEB-INF/lib/
EXPOSE 8080

