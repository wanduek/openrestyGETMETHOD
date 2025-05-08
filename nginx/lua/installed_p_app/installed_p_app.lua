local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"
local lua_query = require "lua_query"
local response = require "response"

-- p_app 생성
local function create_p_app(db, p_app_code, granted_abilities, channel_id)
    local sql = string.format(
        "INSERT INTO p_apps (p_app_code, granted_abilities, channel_id) " ..
        "VALUES (%s, %s, %d) RETURNING id, p_app_code, granted_abilities",
        ngx.quote_sql_str(p_app_code),
        ngx.quote_sql_str(granted_abilities),
        channel_id
    )
    local res = db:query(sql)
    return res
end

-- 요청 본문 파싱
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.p_app_code or not data.granted_abilities then
    return response.bad_request("pAppCode and grantedAbilities are required")
end

-- 사용자 정보 추출
local user_id = ngx.ctx.user_id

-- 채널 정보 추출
local channel_id = ngx.ctx.channel_id

-- DB 연결
local db = postgre.new()

-- 사용자, 프로필, 채널 정보 조회
local user, err = lua_query.get_user_by_id(db, user_id)
if not user then 
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
    return
end

-- seller의 main_profile 조회
local main_profile = lua_query.get_main_profile(db, user_id)
if not main_profile then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
    return
end

-- channel 조회
local channel = lua_query.get_channel_by_id(db, channel_id)
-- if not channel then
--     ngx.status = 404
--     ngx.say(cjson.encode({ error = err }))
--     return
-- end

-- p_app 생성
local p_app_res = create_p_app(db, data.p_app_code, data.granted_abilities, channel_id)
if not p_app_res or not p_app_res[1] then
    return response.internal_server_error("Failed to create p_app")
end

-- installedPApps 구성
local installedPApps = {}
for _, app in ipairs(p_app_res) do
    installedPApps[app.p_app_code] = {
        grantedAbilities = { 
            app.granted_abilities 
        },
        id = app.id
    }
end

local jti = jwt.custom_random_jti(32) 

local payload = jwt.sign{
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    sub = user.type .. ":" .. user.id,
    typ = "access",
    seller = {
        distinctId = user.distinct_id,
        email = data.email,  -- 사용자가 제공한 이메일 정보
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
    }
}
if not payload then
    return response.internal_server_error("Failed to create JWT: " .. (err or "unknown error"))
end

local data = {
    message = "Channel created successfully",
    channel_id = channel_id,
    pAppCode = data.p_app_code,
    grantedAbilities = data.granted_abilities,
    token = payload
}
-- 성공 응답
response.success(data)
