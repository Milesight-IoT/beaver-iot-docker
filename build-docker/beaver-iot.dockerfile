ARG BASE_API_IMAGE=milesight/beaver-iot-api
ARG BASE_WEB_IMAGE=milesight/beaver-iot-web

FROM ${BASE_WEB_IMAGE} AS web

FROM ${BASE_API_IMAGE} AS monolith
COPY --from=web /web /web
RUN apk add --no-cache envsubst nginx nginx-mod-http-headers-more
COPY nginx/envsubst-on-templates.sh /envsubst-on-templates.sh
COPY nginx/main.conf /etc/nginx/nginx.conf
COPY nginx/templates /etc/nginx/templates

ENV BEAVER_IOT_API_HOST=localhost
ENV BEAVER_IOT_API_PORT=9200
ENV BEAVER_IOT_WEBSOCKET_PORT=9201

EXPOSE 80
EXPOSE 9200
EXPOSE 9201

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/sh", "-c", "/envsubst-on-templates.sh && nginx && java -Dloader.path=${HOME}/beaver-iot/integrations ${JAVA_OPTS} -jar /application.jar ${SPRING_OPTS}"]
