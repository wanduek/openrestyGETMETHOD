local cjson = require "cjson"
local jwt = require "middleware.jwt"
local postgre = require "db.postgre"

-- JWT 토큰 파싱
local token = jwt.get_token_from_request()
local verified, payload = jwt.verify(token)

if not verified or not payload or not payload.sub then
    ngx.status = 401
    ngx.say(cjson.encode({ error = "Invalid token" }))
    return ngx.exit(ngx.HTTP_OK)
end

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.channel_id then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "channel_id is required" }))
    return ngx.exit(ngx.HTTP_OK)
end

local user_id = payload.sub
local channel_id = data.channel_id

-- DB 연결
local db = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to DB" }))
    return ngx.exit(ngx.HTTP_OK)
end

-- 채널 소속 여부 확인
local check_sql = string.format(
    "SELECT 1 FROM user_channels WHERE user_id = %s AND channel_id = %s",
    ngx.quote_sql_str(user_id), ngx.quote_sql_str(channel_id)
)

local check_res = db:query(check_sql)

if not check_res or #check_res == 0 then
    ngx.status = 403
    ngx.say(cjson.encode({ error = "User does not belong to this channel" }))
    return ngx.exit(ngx.HTTP_OK)
end

-- access 통과 
ngx.ctx.user_id = user_id
ngx.ctx.channel_id = channel_id
