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
    "INSERT INTO channels (name) VALUES (%s) RETURNING id, base_currency, status",
    ngx.quote_sql_str(data.name)
)

local res = db:query(insert_sql)
if not res or not res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create channel" }))
    return
end

local channel_id = res[1].id
local base_currency = res[1].base_currency
local channel_status = res[1].status

-- jwt 미들웨어에서 전달된 값
local ctx_user_id = ngx.ctx.user_id
if not ctx_user_id then
    ngx.status = 401
    ngx.say(cjson.encode({ error = "UnauthorizedL no user context"}))
end

local _, id_str = string.match(ctx_user_id, "([^:]+):([^:]+)")
local user_id = tonumber(id_str)

if not user_id then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "Invalid user_id format" }))
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

local user_id = user_res[1].id
local role = user_res[1].role
local type = user_res[1].type
local distinct_id = user_res[1].distinct_id
local is_global_seller = user_res[1].is_global_seller
local status = user_res[1].status

-- 유저와 채널 연결
local user_channel_sql = string.format(
    "INSERT INTO user_channels (user_id, channel_id) VALUES (%d, %d)",
    user_id, channel_id
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

-- mainProfile 조회
local main_profile_query = string.format(
    "SELECT id, nickname FROM main_profiles WHERE user_id = %d", user_id
)

local main_profile_res = db:query(main_profile_query)

local main_profile_id = main_profile_res[1].id
local main_profile_nickname = main_profile_res[1].nickname

function custom_random_jti(length)
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    local result = {}

    for i = 1, length do
        local rand = math.random(1, #chars)
        table.insert(result, chars:sub(rand, rand))
    end

    return table.concat(result)
end

local jti = custom_random_jti(32)

-- local app_data_query = string.format("SELECT id, p_app_code, granted_abilities FROM p_app")

-- local app_data_res = db:query(app_data_query)



-- local installedPApps = {}
-- for _, app in ipairs(app_data_res) do
--     installedPApps[app.p_app_code] = {
--         grantedAbilities = app.granted_abilities,
--         id = app.id
--     }
-- end

-- local profile_query = string.format("SELECT * FROM profiles")

-- local profile_res = db:query(profile_query)

-- local profile = {}

-- for _, channel_profiles in ipairs(profile_res) do
--     profile = {
--         age = channel_profiles.age,
--         birthYear = channel_profiless.birthYear,
--         certifiedAge = channel_profiles.certified_age,
--         distinctId = channel_profiles.distinct_id,
--         gender = channel_profiles.gender,
--         id = channel_profiles.id,
--         imageSrc = channel_profiles.image_src,
--         isFeatured = channel_profiles.is_featured,
--         nickname = channel_profiles.nickname
--     }
-- end 

-- JWT 생성
local payload = ({
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    seller = {
        distinctId = distinct_id ,
        email = data.email,
        id = user_id,
        identity = "IDENTITY:" .. type .. ":" .. user_id,
        isGlobalSeller = is_global_seller,
        mainProfile = {
            id = main_profile_id,
            nickname = main_profile_nickname
        },
        operatingChannels = {
            [tostring(channel_id)] = {
                baseCurrency = base_currency,
                -- installedPApps = installedPApps
            },
            -- profile = profile,
            status = channel_status,
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
        role = role,
        status = status,
        type = type
    },
    sub = type .. ":" .. tostring(user_id),
    typ = "access"
})

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
