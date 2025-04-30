local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"

local token, token_err = jwt.get_token_from_request()
if not token then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = token_err }))
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local ok, payload_or_err = jwt.verify(token)
if not ok then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = payload_or_err }))
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local payload = payload_or_err
ngx.ctx.user_id = payload.sub

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
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(cjson.encode({ error = "Missing channel_id in JWT" }))
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

ngx.ctx.channel_id = channel_id
