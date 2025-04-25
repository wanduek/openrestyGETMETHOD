local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.name then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Channel name is required" }))
    return
end

-- DB 연결
local db = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to DB" }))
    return
end

-- 채널 생성
local insert_sql = string.format(
    "INSERT INTO channels (name) VALUES (%s) RETURNING id",
    ngx.quote_sql_str(data.name)
)

local res = db:query(insert_sql)
if not res or not res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create channel" }))
    return
end

local channel_id = res[1].id
local user_id = ngx.ctx.user_id

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

-- 유저와 채널 연결
local user_channel_sql = string.format(
    "INSERT INTO user_channels (user_id, channel_id) VALUES (%s, %s)",
    ngx.quote_sql_str(user_id),
    ngx.quote_sql_str(channel_id)
)

local user_channel_res = db:query(user_channel_sql)
if not user_channel_res then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to map user to channel" }))
    return
end

-- 채널 목록 업데이트 (혹시 다른 채널에 이미 가입된 경우)
local channel_ids = ngx.ctx.channel_ids or {}
table.insert(channel_ids, channel_id)

-- JWT 토큰 생성
local payload = {
    channelId = channel_id,  -- 단일 채널만 넣기
    sub = tostring(user.id),
    email = user.email,
    iat = ngx.time(),
    exp = ngx.time() + 3600
}

local new_token, err = jwt.sign(payload)
if not new_token then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create new token", detail = err }))
    return
end

-- 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "Channel created successfully",
    channel_id = channel_id,  
    token = new_token
}))
