-- access.lua
local jwt = require "middleware.jwt"
local response =require "response"

local token =jwt.get_token_from_request()
local ok, payload = jwt.verify(token)

if not ok then
    return response.unauthorized("Invalid JWT token: " .. (payload or "unknown"))
end
-- 유저 정보 추출
if not payload.seller.id then
    return response.not_found("Not found user_id in payload")
end

ngx.ctx.user_id = payload.seller.id