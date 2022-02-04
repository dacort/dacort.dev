FROM openjdk:8 AS build-stage

RUN apt-get update && apt-get install -y \
    maven \
    zip

WORKDIR /usr/src/ktwit
ADD https://github.com/jcustenborder/kafka-connect-twitter/archive/refs/tags/0.3.34.tar.gz /usr/src/ktwit/

RUN tar xzf 0.3.34.tar.gz && \
    cd kafka-connect-twitter-0.3.34 && \
    mvn clean package

RUN tar xzf kafka-connect-twitter-0.3.34/target/kafka-connect-twitter-0.3-SNAPSHOT.tar.gz && \
    zip -rj kafka-connect-twitter-0.3.34.zip usr/share/kafka-connect/kafka-connect-twitter/

FROM scratch AS export-stage
COPY --from=build-stage /usr/src/ktwit/*.zip /