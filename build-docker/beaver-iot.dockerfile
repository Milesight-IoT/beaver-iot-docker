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
ENV MQTT_BROKER_WS_PATH=/mqtt
ENV MQTT_BROKER_WS_PORT=80
ENV MQTT_BROKER_WSS_PORT=443
ENV MQTT_BROKER_MOQUETTE_WEBSOCKET_PORT=8083

EXPOSE 80
EXPOSE 9200
EXPOSE 1883
EXPOSE 8083

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/sh", "-c", "/envsubst-on-templates.sh && nginx && java -Dloader.path=${HOME}/beaver-iot/integrations ${JAVA_OPTS} -jar /application.jar ${SPRING_OPTS}"]
