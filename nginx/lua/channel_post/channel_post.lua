local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"
local lua_query = require "lua_query"

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
    "INSERT INTO channels (name) VALUES (%s) RETURNING id, base_currency, status",
    ngx.quote_sql_str(data.name)
)

local res = db:query(insert_sql)
if not res or not res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create channel" }))
    return
end

local channel = res[1]

-- 사용자 정보 가져오기
local user, err = lua_query.get_user_by_id(db)

if not user then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
    return
end

-- 유저와 채널 연결
local user_channel_sql = string.format(
    "INSERT INTO user_channels (user_id, channel_id) VALUES (%d, %d)",
    user.id, channel.id
)

local user_channel_res = db:query(user_channel_sql)
if not user_channel_res then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to map user to channel" }))
    return
end

-- 채널 목록 업데이트 (혹시 다른 채널에 이미 가입된 경우)
local channel_ids = ngx.ctx.channel_ids or {}
table.insert(channel_ids, channel.id)

-- mainProfile 조회
local main_profile, err = lua_query.get_main_profile(db, user.id)
if not main_profile then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
end

local main_profile = res[1]

local jti = jwt.custom_random_jti(32)

-- JWT 생성
local payload = jwt.sign({
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = user.distinct_id ,
        email = user.email,
        id = user.id,
        identity = "IDENTITY:" .. user.type .. ":" .. user.id,
        isGlobalSeller = user.is_global_seller,
        mainProfile = {
            id = main_profile.id,
            nickname = main_profile.nickname
        },
        operatingChannels = {
            [tostring(channel.id)] = {
                baseCurrency = channel.base_currency,
                -- installedPApps = installedPApps
            },
            -- profile = profile,
            status = channel.status,
        },
        pAppAdditionalPermissions = {
            ["*"] = true
        },
        pAppPermission = {
            "*"
        },
        permissions = {
            "*"
        },
        role = user.role,
        status = user.status,
        type = user.type
    },
    sub = user.type .. ":" .. tostring(user.id),
    typ = "access"
})

-- 응답
ngx.status = 200
ngx.say(cjson.encode({
    message = "Channel created successfully",
    channel_id = channel.id,  
    token = payload
}))
