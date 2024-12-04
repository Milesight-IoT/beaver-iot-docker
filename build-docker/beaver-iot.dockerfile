ARG DOCKER_REPO=beaver-iot
ARG BASE_SERVER_IMAGE=milesight/beaver-iot-server
ARG BASE_WEB_IMAGE=milesight/beaver-iot-web

FROM ${BASE_WEB_IMAGE} AS web

FROM ${BASE_SERVER_IMAGE} AS monolith
COPY --from=web /web /web
RUN apk add --no-cache envsubst nginx nginx-mod-http-headers-more
COPY nginx/envsubst-on-templates.sh /envsubst-on-templates.sh
COPY nginx/main.conf /etc/nginx/nginx.conf
COPY nginx/templates /etc/nginx/templates

ENV SERVER_HOST=172.17.0.1
ENV SERVER_PORT=9200
ENV WEBSOCKET_PORT=9201

EXPOSE 80
EXPOSE 9200
EXPOSE 9201

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/sh", "-c", "/envsubst-on-templates.sh && nginx && java -Dloader.path=${HOME}/beaver-iot/plugins ${JAVA_OPTS} -jar /application.jar ${SPRING_OPTS}"]
