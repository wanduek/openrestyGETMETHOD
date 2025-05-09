FROM openresty/openresty:latest
# FROM openresty/openresty:1.21.4.2-2-alpine

COPY nginx/server/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx/lua/ /usr/local/openresty/nginx/lua/
# COPY nginx/html/ /usr/local/openresty/nginx/html/




