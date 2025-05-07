-- access.lua
local jwt = require "middleware.jwt"
local cjson = require "cjson"

local token =jwt.get_token_from_request()
local ok, payload = jwt.verify(token)

if not ok then
    ngx.status = 401
    ngx.say(cjson.encdode({ error = "Invalid JWT token: " .. (payload or "unknown") }))
end
-- 유저 정보 추출
if not payload.seller.id then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "Not found user_id in payload"}))
    return
    
end

ngx.ctx.user_id = payload.seller.id