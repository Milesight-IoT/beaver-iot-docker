FROM maven:3.8.3-openjdk-17 AS api-builder

ARG API_GIT_REPO_URL
ARG API_GIT_BRANCH

WORKDIR /
RUN git clone ${API_GIT_REPO_URL} beaver-iot-api

WORKDIR /beaver-iot-api
RUN git checkout ${API_GIT_BRANCH} && mvn package -U -Dmaven.repo.local=.m2/repository -DskipTests -am -pl application/application-standard


FROM amazoncorretto:17-alpine3.20-jdk AS api
COPY --from=api-builder /beaver-iot-api/application/application-standard/target/application-standard-exec.jar /application.jar

# Create folder for spring
VOLUME /tmp
VOLUME /beaver-iot

ENV JAVA_OPTS=""
ENV SPRING_OPTS=""

EXPOSE 9200
EXPOSE 9201

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/sh", "-c", "java -Dloader.path=${HOME}/beaver-iot/plugins ${JAVA_OPTS} -jar /application.jar ${SPRING_OPTS}"]
