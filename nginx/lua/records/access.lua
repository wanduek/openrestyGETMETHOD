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

if not ok then
    return
end

local channel_id_from_header = ngx.var.http_x_channel_id

-- 요청 헤더에서 channel_id 추출
if not channel_id_from_header then
    ngx.status = ngx.HTTP_BAD_REQUSET
    ngx.say(cjson.encode({ error = "Missing X-channel_id header" }))
    return
end

-- JWT payload와 channel_id와 비교
if claims.channel_id ~= channel_id_from_header then
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say(cjson.encode({ error = "Unauthorized channel access"}))
    return
end

-- JWT의 토근 만료
local is_valid = jwt.verify(token)
if not is_valid then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid or expired token"}))
    return
end

local limit = ngx.shared.rate_limit
local uri = ngx.var.uri

-- rate limit
local req, err = limit:incr(uri, 1, 0, 10) -- 초기값0 , TTL10초
if not req then
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

if req > 100 then
    ngx.status = ngx.HTTP_TOO_MANY_REQUESTS
    ngx.say("rate limit exceeded")
    return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end
