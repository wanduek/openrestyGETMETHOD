local uri = ngx.var.uri

if uri == "/seller/api/v1/records" then
    ngx.req.set_uri("/records")
    ngx.log(ngx.ERR, "After rewrite URI: ", ngx.var.uri)
end