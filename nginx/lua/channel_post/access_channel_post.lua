-- access.lua
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"

local token =jwt.get_token_from_request()
local _, payload = jwt.verify(token)

-- 유저 정보 저장 
ngx.ctx.user_id = payload.sub
ngx.ctx.channelIds = payload.channelIds

