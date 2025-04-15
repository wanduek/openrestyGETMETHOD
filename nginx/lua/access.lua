local limit = ngx.shared.rate_limit
local key = ngx.var.binary_remote_addr

-- rate limit
local req, err = limit:incr(key, 1, 0, 10) -- 초기값0 , TTL10초
if not req then
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

if req > 100 then
    ngx.status = ngx.HTTP_TOO_MANY_REQUESTS
    ngx.say("rate limit exceeded")
    return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end

local cache = ngx.shared.local_cache
local cached = cache:get("records:"..key)
if cached then
    ngx.say(cached)
    return ngx.exit(ngx.HTTP_OK)
end