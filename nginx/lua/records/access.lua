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

-- Authorization 헤더에서 토큰을 추출
local token = jwt.get_token_from_request()

-- 토큰 검증
local ok, claims = jwt.verify(token)

-- 토큰 검증 실패 시 응답
if not ok then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Invalid token" }))
    return
end

-- X-Channel-Id 헤더 값 가져오기
local headers = ngx.req.get_headers()
local channel_id_from_header = headers["X-Channel-Id"]

if type(channel_id_from_header) == "table" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Mutiple X-Channel-Id headers are not allowed" }))
end

-- X-Channel-Id가 비어 있거나 null인 경우 에러 처리
if not channel_id_from_header or channel_id_from_header == "" or channel_id_from_header == "null" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Missing or invalid X-Channel-Id header" }))
    return
end

-- channel_id_from_header 값을 숫자로 변환
local channel_id_from_header_num = tonumber(channel_id_from_header)

-- 변환 실패 시 처리
if not channel_id_from_header_num then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "X-Channel-Id must be a valid number" }))
    return
end

-- JWT payload와 channelId 비교 (숫자 비교)
if claims.channelId ~= channel_id_from_header_num then
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say(cjson.encode({ error = "Unauthorized channel access" }))
    return
end

-- 레이트 리미트 로직
local limit = ngx.shared.rate_limit
local uri = ngx.var.uri

-- 요청 수 증가 (초기값 0, TTL 10초)
local req = limit:incr(uri, 1, 0, 10)

-- 요청 실패 시 내부 서버 오류 처리
if not req then
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.say(cjson.encode({ error = "Failed to increment request count" }))
    return
end

-- 레이트 리미트 초과 시 처리
if req > 100 then
    ngx.status = ngx.HTTP_TOO_MANY_REQUESTS
    ngx.say(cjson.encode({ error = "Rate limit exceeded" }))
    return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end
