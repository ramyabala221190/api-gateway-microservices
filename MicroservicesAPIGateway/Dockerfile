# Use the official Express Gateway image as the base
FROM express-gateway

ARG targetENV

# RUN test -f combined.log || touch combined.log

# RUN test -f error.log || touch error.log

# RUN ln -s -f /dev/stdout combined.log && ln -s -f /dev/stderr error.log


#WORKDIR /var/lib/eg/
# ADD /docker/certs/root_ca.crt /usr/local/share/ca-certificates/
# # Update the CA certificates in the container

# RUN cat /usr/local/share/ca-certificates/root_ca.crt >> /etc/ssl/certs/ca-certificates.crt && \
#     apk --no-cache add \
#         curl

# RUN apk update && \
#     apk add ca-certificates && \
#     update-ca-certificates && \
#     rm -rf /var/cache/apk/*

# RUN apk update && apk add ca-certificates

# RUN apk add --upgrade ca-certificates

# COPY /docker/certs/rootCA.crt /usr/local/share/ca-certificates/

# RUN chmod 644 /usr/local/share/ca-certificates/rootCA.crt

# RUN update-ca-certificates

# ENV NODE_EXTRA_CA_CERTS=/var/lib/certs/rootCA.crt

COPY /MicroservicesAPIGateway/config/models /var/lib/eg/models
COPY /MicroservicesAPIGateway/plugins /var/lib/eg/plugins
COPY /MicroservicesAPIGateway/config/system.config.yml /var/lib/eg/system.config.yml
COPY /MicroservicesAPIGateway/config/gateway.config.${targetENV}.yml /var/lib/eg/gateway.config.yml
