local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"
local lua_query = require "lua_query"
local response = require "response"
local payload_builder = require "middleware.payload_build"

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.name then
    return response.bad_request("Channel name is required")
end

-- DB 연결
local db = postgre.new()

-- 채널 생성
local insert_sql = string.format(
    "INSERT INTO channels (name) VALUES (%s) RETURNING id, base_currency, status",
    ngx.quote_sql_str(data.name)
)

local res = db:query(insert_sql)
if not res or not res[1] then
    return response.internal_server_error("Failed to create channel")
end

local channel = res[1]

local user_id = ngx.ctx.user_id

-- 사용자 정보 가져오기
local user = lua_query.get_user_by_id(db, user_id)

-- 유저와 채널 연결
local user_channel_sql = string.format(
    "INSERT INTO user_channels (user_id, channel_id) VALUES (%d, %d)",
    user_id, channel.id
)

local user_channel_res = db:query(user_channel_sql)
if not user_channel_res then
    return response.internal_server_error("Failed to map user to channel")
end

-- 채널 목록 업데이트 (혹시 다른 채널에 이미 가입된 경우)
local channel_ids = ngx.ctx.channel_ids or {}
table.insert(channel_ids, channel.id)

-- mainProfile 조회
local main_profile = lua_query.get_main_profile(db, user_id)

-- 커넥션 풀에 반납
postgre.keepalive(db)

local payload = payload_builder.build({
    channel_id = channel.id,
    user = user,
    main_profile = main_profile
})

local token = jwt.sign(payload)

local success_data = {
    message = "Channel created successfully",
    channel_id = channel.id,  
    token = token
}

-- 성공 응답
response.success(success_data)


