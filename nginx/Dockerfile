FROM nginx:alpine

ARG targetENV

RUN echo ${targetENV}

# COPY /nginx/nginx.${targetENV}.conf /etc/nginx/templates/default.conf.template

COPY /nginx/nginx_default.conf /etc/nginx/nginx.conf