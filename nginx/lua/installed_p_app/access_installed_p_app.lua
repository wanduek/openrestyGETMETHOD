local jwt = require "middleware.jwt"
local response = require "response"

-- 요청 메서드 확인
if ngx.req.get_method() ~= "POST" then
    return response.method_not_allowed("Method not allowed")
end

local token, err = jwt.get_token_from_request()
if not token then
    return response.unauthorized(err)
end

local ok, payload = jwt.verify(token)
if not ok then
    return response.unauthorized("Invalid JWT token: " .. (payload or "unknown"))
end

ngx.ctx.user_id = payload.seller.id

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
