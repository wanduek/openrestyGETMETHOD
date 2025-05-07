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

-- channel 조회
local channel_sql = string.format("SELECT id, base_currency, status FROM channels WHERE id = %s", channel_id)

local channel_res = db:query(channel_sql)

if not channel_res or not channel_res[1] then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "The channel was not found"}))
end

local channel = channel_res[1]

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
    "SELECT * FROM users WHERE id = %s",
    ngx.quote_sql_str(user_id)
)
local user_res = db:query(user_sql)

if not user_res or not user_res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to fetch user information" }))
    return
end

local user = user_res[1]
local user_id = user_res[1].id

-- main profile 조회
local main_profile_sql = string.format("SELECT * FROM main_profiles where user_id = %s ", user_id)

local main_profile_res = db:query(main_profile_sql)

if not main_profile_res or not main_profile_res[1] then
    ngx.status = 404 
    ngx.say(cjson.encode({ error = "The main profile was not found" }))
    return
end

local main_profile = main_profile_res[1]

-- channel_memebers 조회
local channel_membership_sql = string.format("SELECT id, channel_id, profile_id FROM channel_memberships WHERE channel_id = %s", channel_id)

local channel_memebership_res = db:query(channel_membership_sql)

if not channel_memebership_res or not channel_memebership_res[1] then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "The channel_membership was not found"}))
    return
end

local profile_id = channel_memebership_res[1].profile_id

-- profile 조회
local profile_sql = string.format("SELECT * FROM profiles WHERE id = %s", profile_id)

local profile_res = db:query(profile_sql)

if not profile_res or not profile_res[1] then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "The profile was not found"}))
    return
end

-- profile 구성
local profile = {
    id = profile_res[1].id,
    nickname = profile_res[1].nickname,
    age = profile_res[1].age,
    birthYear = profile_res[1].birth_year,
    certifiedAge = profile_res[1].certified_age,
    gender = profile_res[1].gender,
    imageSrc = profile_res[1].image_src,
    isFeatured = profile_res[1].is_featured,
    distinctId = profile_res[1].distinct_id
}

-- installedPApps 조회

local installedPApps_sql = string.format("SELECT * FROM p_apps WHERE channel_id = %s",channel_id)

local installedPApps_res = db:query(installedPApps_sql)
if not installedPApps_res or not installedPApps_res[1] then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "The pApp was not found"}))
    return
end

-- installedPApps 구성
local installedPApps = {}
for _, app in ipairs(installedPApps_res) do
    installedPApps[app.p_app_code] = {
        grantedAbilities = { 
            app.granted_abilities 
        },
        id = app.id
    }
end

-- JWT 생성
local jti = jwt.custom_random_jti(32) 

local payload = {
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
    sub = user.type .. ":" .. tostring(user.id),
    typ = "access",
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
