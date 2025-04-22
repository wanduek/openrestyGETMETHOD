FROM openresty/openresty:latest

COPY nginx/nginx.conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx/lua/ /usr/local/openresty/nginx/lua/
COPY nginx/html/ /usr/local/openresty/nginx/html/




