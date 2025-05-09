local jwt = require "middleware.jwt"
local response = require "response"

-- 요청 메서드 확인
if ngx.req.get_method() ~= "GET" then
    return response.method_not_allowed("Method not allowed")
end

-- Authorization 헤더에서 토큰을 추출
local token = jwt.get_token_from_request()

-- 토큰 검증
local ok, payload = jwt.verify(token)

-- 토큰 검증 실패 시 응답
if not ok then
    return response.unauthorized("Invalid token")
end

-- X-Channel-Id 헤더 값 가져오기
local headers = ngx.req.get_headers()
local channel_id_from_header = headers["X-Channel-Id"]

-- X-Channel-Id가 여러 번 포함되었는지 확인
if type(channel_id_from_header) == "table" then
    return response.bad_request("Mutiple X-Channel-Id headers are not allowed")
end

-- X-Channel-Id가 비어 있거나 null인 경우 에러 처리
if not channel_id_from_header or channel_id_from_header == "" or channel_id_from_header == "null" then
    return response.bad_request("Missing or invalid X-Channel-Id header")
end

-- channel_id_from_header 값을 숫자로 변환
local channel_id_from_header_num = tonumber(channel_id_from_header)

-- 변환 실패 시 처리
if not channel_id_from_header_num then
    return response.bad_request("X-Channel-Id must be a valid number")
end

-- operatingChannels에서 channel_id 추출
local function extract_first_channel_id(operatingChannels)
    if type(operatingChannels) ~= "table" then return nil end
    for channel_id_str, _ in pairs(operatingChannels) do
        return tonumber(channel_id_str)
    end
    return nil
end

local channel_id = extract_first_channel_id(payload.seller and payload.seller.operatingChannels)
if not channel_id then
    return response.unauthorized("Missing channel_id in JWT")
end

ngx.ctx.channel_id = channel_id



-- 레이트 리미트 로직
local limit = ngx.shared.rate_limit
local uri = ngx.var.uri

-- 요청 수 증가 (초기값 0, TTL 10초)
local req = limit:incr(uri, 1, 0, 10)

-- 요청 실패 시 내부 서버 오류 처리
if not req then
    return response.too_many_requests("Failed to increment request count")
end

-- 레이트 리미트 초과 시 처리
if req > 100 then
    return response.too_many_requests("Rate limit exceeded")
end
