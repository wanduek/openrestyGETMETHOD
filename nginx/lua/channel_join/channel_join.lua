local cjson = require "cjson"
local postgre  = require "db.postgre"
local jwt = require "middleware.jwt"

if ngx.req.get_method() ~= "POST" then
    ngx.status = 405
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ error = "Method not allowed" }))
    return
end

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.channel_id then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "channel_id is required" }))
    return
end

local channel_id = data.channel_id
local user_id = ngx.ctx.user_id

-- DB 연결
local db = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to DB" }))
    return
end

-- 사용자가 해당 채널에 속해있는지 확인
local check_sql = string.format(
    "SELECT 1 FROM user_channels WHERE user_id = %s AND channel_id = %s",
    ngx.quote_sql_str(user_id), ngx.quote_sql_str(channel_id)
)

local check_res = db:query(check_sql)

if not check_res or #check_res == 0 then
    ngx.status = 403
    ngx.say(cjson.encode({ error = "User does not belong to this channel" }))
    return
end

-- 사용자 정보 가져오기
local user_sql = string.format(
    "SELECT id, email FROM users WHERE id = %s",
    ngx.quote_sql_str(user_id)
)
local user_res = db:query(user_sql)

if not user_res or not user_res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to fetch user information" }))
    return
end

local user = user_res[1]

-- JWT 토큰 생성 (단일 채널 기반)
local payload = {
    channelId = channel_id,
    sub = tostring(user.id),
    email = user.email,
    iat = ngx.time(),
    exp = ngx.time() + 3600
}

local token, err = jwt.sign(payload)
if not token then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create token", detail = err }))
    return
end

ngx.status = 200
ngx.say(cjson.encode({
    message = "Successfully joined channel",
    channelId = channel_id,
    token = token
}))
