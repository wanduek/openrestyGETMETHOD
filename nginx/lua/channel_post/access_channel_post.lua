-- access.lua
local jwt = require "middleware.jwt"
local cjson = require "cjson"

local token =jwt.get_token_from_request()
local _, payload = jwt.verify(token)

-- 유저 정보 저장 
ngx.ctx.user_id = payload.seller.id

if not payload.seller.id then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "Not found user_id in payload"}))
    return
    
end

