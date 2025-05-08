local cjson = require "cjson"
local jwt = require "middleware.jwt"
local postgre = require "db.postgre"
local response = require "response"
local lua_query = require "lua_query"
if ngx.req.get_method() ~= "POST" then
    return response.method_not_allowed("Method not allowed")
end

-- JWT 토큰 파싱
local token = jwt.get_token_from_request()
local verified, payload = jwt.verify(token)

if not verified or not payload or not payload.seller.id then
    return response.unauthorized("Invalid token")
end

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.channel_id then
    return response.bad_request("channel_id is required")
end

-- DB 연결
local db = postgre.new()

local user_id = payload.seller.id
local channel_id = data.channel_id

-- 채널 소속 여부 확인
lua_query.get_user_channel(db, user_id, channel_id)

ngx.ctx.user_id = user_id
ngx.ctx.channel_id = channel_id
