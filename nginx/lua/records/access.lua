local cjson = require "cjson"
local jwt = require "middleware.jwt"

-- 요청 메서드 확인
if ngx.req.get_method() ~= "GET" then
    ngx.status = 405
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Method not allowed"
    }))
    return
end

local token = jwt.get_token_from_request()
local ok, claims =jwt.verify(token)

local headers = ngx.req.get_headers()
local channel_id_from_header = headers["X-Channel-Id"]

if not ok then
    return
end

-- X-Channel-Id의 null 값 유무 판별
if channel_id_from_header == "" or channel_id_from_header == "null" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Missing X-channel_id header" }))
    return
end

-- JWT payload와 channelId와 비교
if claims.channelIds ~= channel_id_from_header then
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say(cjson.encode({ error = "Unauthorized channel access"}))
    return
end

local limit = ngx.shared.rate_limit
local uri = ngx.var.uri

-- rate limit
local req = limit:incr(uri, 1, 0, 10) -- 초기값0 , TTL10초
if not req then
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

if req > 100 then
    ngx.status = ngx.HTTP_TOO_MANY_REQUESTS
    ngx.say("rate limit exceeded")
    return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end
