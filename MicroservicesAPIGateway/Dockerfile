# Use the official Express Gateway image as the base
FROM express-gateway

ARG targetENV

COPY /MicroservicesAPIGateway/config/models /var/lib/eg/models
COPY /MicroservicesAPIGateway/plugins /var/lib/eg/plugins
COPY /MicroservicesAPIGateway/config/system.config.yml /var/lib/eg/system.config.yml
COPY /MicroservicesAPIGateway/config/gateway.config.yml /var/lib/eg/gateway.config.yml
# COPY /MicroservicesAPIGateway/config/gateway.config.${targetENV}.yml /var/lib/eg/gateway.config.yml
