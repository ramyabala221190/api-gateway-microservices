FROM nginx:alpine

ARG targetENV

COPY /nginx/nginx.${targetENV}.conf /etc/nginx/templates/default.conf.template

COPY /nginx/nginx_default.conf /etc/nginx/nginx.conf

# RUN apk add --upgrade ca-certificates

# COPY /docker/certs/rootCA.crt /usr/local/share/ca-certificates/

# RUN chmod 644 /usr/local/share/ca-certificates/rootCA.crt

# RUN update-ca-certificates