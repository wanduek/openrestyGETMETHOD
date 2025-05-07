local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"

local token = jwt.get_token_from_request()

local ok, payload = jwt.verify(token)

if not ok then
    ngx.status = 401
    ngx.say(cjson.encdode({ error = "Invalid JWT token: " .. (payload or "unknown") }))
end
if not payload.seller.id then
    ngx.statues = 404
    ngx.say = (cjson.encode({ error = "Not found user_id in payload"}))
end

ngx.ctx.user_id = payload.seller.id

-- operatingChannels에서 channel_id 추출
local function extract_first_channel_id(operatingChannels)
    if type(operatingChannels) ~= "table" then
        ngx.log(ngx.ERR, "operatingChannels is not a table: ", type(operatingChannels))
        return nil
    end
    for channel_id_str, _ in pairs(operatingChannels) do
        local id = tonumber(channel_id_str)
        if id then
            return id
        else
            ngx.log(ngx.ERR, "Failed to convert channel_id_str to number: ", channel_id_str)
        end
    end
    return nil
end

local operatingChannels = payload.seller and payload.seller.operatingChannels
local channel_id = extract_first_channel_id(operatingChannels)

if not channel_id then
    ngx.status = 401
    ngx.say(cjson.encode({ error = "Missing or invalid channel_id in JWT" }))
    return 
end

ngx.ctx.channel_id = channel_id

