local cjson = require "cjson"
local postgre  = require "db.postgre"
local jwt = require "middleware.jwt"
local lua_query = require "lua_query"



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

-- channel 조회
local channel, err = lua_query.get_channel_by_id(db, channel_id)

if not channel then
    ngx.status = 404
    ngx.say(cjson.encdoe({ error = err}))
    return
end

-- 사용자가 해당 채널에 속해있는지 확인
local user_channel, err = lua_query.get_user_channel(db, user_id, channel_id)
if not user_channel then
    ngx.status = 403
    ngx.say(cjson.encode({ error = err }))
    return
end

-- 사용자 정보 가져오기
local user, err = lua_query.get_user_by_id(db, user_id)
if not user then
    ngx.status = 403
    ngx.say(cjson.encode({ error = err}))
    return
end

-- main profile 조회
local main_profile, err = lua_query.get_main_profile(db, user_id)
if not main_profile then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err}))
end

-- channel_memebers 조회
local channel_membership, err = lua_query.get_channel_membership(db, channel_id)

if not channel_membership then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
    return
end

local profile_id = channel_membership.profile_id

-- profile 조회
local profile, err = lua_query.get_profile_by_id(db, profile_id)
if not profile then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err}))
    return
end

-- installedPApps 조회
local installedPApps, err = lua_query.get_installed_papps(db, channel_id)
if not installedPApps then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err}))
end

-- JWT 생성
local jti = jwt.custom_random_jti(32) 

local payload = jwt.sign{
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = user.distinct_id,
        email = user.email, 
        id = user.id,
        identity = "IDENTITY:" .. user.type .. ":" .. user.id,
        isGlobalSeller = user.is_global_seller,
        mainProfile = {
            id = main_profile.id,
            nickname = main_profile.nickname
        },
        operatingChannels = {
            [channel_id] = {
                baseCurrency = channel.base_currency,
                installedPApps = installedPApps,
                profile = profile,
                status = channel.status
            }
        },
        pAppAdditionalPermissions = { ["*"] = true },
        pAppPermission = { "*" },
        permissions = { "*" },
        role = user.role,
        status = user.status,
        type = user.type

    },
    sub = user.type .. ":" .. user.id,
    typ = "access",
}
if not payload then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create token", detail = err }))
    return
end

ngx.status = 200
ngx.say(cjson.encode({
    message = "Successfully joined channel",
    channelId = channel_id,
    token = payload
}))
