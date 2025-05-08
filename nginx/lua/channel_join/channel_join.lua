local cjson = require "cjson"
local postgre  = require "db.postgre"
local jwt = require "middleware.jwt"
local lua_query = require "lua_query"
local response = require "response"



ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.channel_id then
    return response.bad_request("channel_id is required")
end

local channel_id = data.channel_id
local user_id = ngx.ctx.user_id

-- DB 연결
local db = postgre.new()

-- channel 조회
local channel = lua_query.get_channel_by_id(db, channel_id)

-- 사용자가 해당 채널에 속해있는지 확인
lua_query.get_user_channel(db, user_id, channel_id)

-- 사용자 정보 가져오기
local user = lua_query.get_user_by_id(db, user_id)

-- main profile 조회
local main_profile = lua_query.get_main_profile(db, user_id)

-- channel_memebers 조회
local channel_membership = lua_query.get_channel_membership(db, channel_id)

local profile_id = channel_membership.profile_id

-- profile 조회
local profile = lua_query.get_profile_by_id(db, profile_id)

-- installedPApps 조회
local installedPApps = lua_query.get_installed_papps(db, channel_id)

-- jti 생성
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

local data = {
    message = "Successfully joined channel",
    channelId = channel_id,
    token = payload
}

response.success(data)
