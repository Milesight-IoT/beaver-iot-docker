FROM maven:3.8.3-openjdk-17 AS api-builder

ARG API_GIT_REPO_URL
ARG API_GIT_BRANCH
ARG API_MVN_PROFILE=release
ARG API_MVN_SNAPSHOT_REPO_ID=central-portal-snapshots
ARG API_MVN_SNAPSHOT_REPO_URL=https://central.sonatype.com/repository/maven-snapshots/

WORKDIR /
RUN git clone ${API_GIT_REPO_URL} beaver-iot-api

WORKDIR /beaver-iot-api
RUN git checkout ${API_GIT_BRANCH} && mvn package -U -Dmaven.repo.local=.m2/repository -P${API_MVN_PROFILE} -Dsnapshot-repository-id=${API_MVN_SNAPSHOT_REPO_ID} -Dsnapshot-repository-url=${API_MVN_SNAPSHOT_REPO_URL} -DskipTests -am -pl application/application-standard


FROM amazoncorretto:17-alpine3.20-jdk AS api
COPY --from=api-builder /beaver-iot-api/application/application-standard/target/application-standard-exec.jar /application.jar

RUN apk add --no-cache fontconfig ttf-dejavu font-noto font-noto-cjk font-noto-emoji

# Create folder for spring
VOLUME /tmp
VOLUME /beaver-iot

ENV JAVA_OPTS=""
ENV SPRING_OPTS=""
ENV MQTT_BROKER_MQTT_PORT=1883
ENV MQTT_BROKER_WS_PATH=/mqtt
ENV MQTT_BROKER_WS_PORT=""
ENV MQTT_BROKER_MOQUETTE_WEBSOCKET_PORT=8083

EXPOSE 9200
EXPOSE 1883
EXPOSE 8083

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/sh", "-c", "java -Dloader.path=${HOME}/beaver-iot/integrations ${JAVA_OPTS} -jar /application.jar ${SPRING_OPTS}"]
