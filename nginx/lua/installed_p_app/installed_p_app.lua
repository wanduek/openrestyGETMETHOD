local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"

-- 헬퍼 함수: 에러 응답
local function return_error(status, msg)
    ngx.status = status
    ngx.say(cjson.encode({ error = msg }))
    return ngx.exit(status)
end

-- 헬퍼 함수: p_app 생성
local function create_p_app(db, p_app_code, granted_abilities, channel_id)
    local sql = string.format(
        "INSERT INTO p_app (p_app_code, granted_abilities, channel_id) " ..
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
    return_error(ngx.HTTP_BAD_REQUEST, "pAppCode and grantedAbilities are required")
end

-- 사용자 정보 추출
local ctx_user_id = ngx.ctx.user_id
if not ctx_user_id then
    return_error(401, "Unauthorized: no user context")
end

local _, id_str = string.match(ctx_user_id, "([^:]+):([^:]+)")
local user_id = tonumber(id_str)
if not user_id then
    return_error(400, "Invalid user_id format")
end

-- 채널 정보 추출
local channel_id = ngx.ctx.channel_id
if not channel_id then
    return_error(400, "Missing channel_id in context")
end

-- DB 연결
local db = postgre.new()
if not db then
    return_error(500, "Failed to connect to DB")
end

-- 사용자, 프로필, 채널 정보 조회
local user_sql = string.format("SELECT id, role, type, distinct_id, is_global_seller, status FROM users WHERE id = %d", user_id)
local user_res = db:query(user_sql)
if not user_res or not user_res[1] then
    return_error(500, "User not found")
end
local user = user_res[1]

local profile_sql = string.format("SELECT id, nickname FROM main_profiles WHERE user_id = %d", user_id)
local profile_res = db:query(profile_sql)
if not profile_res or not profile_res[1] then
    return_error(500, "Main profile not found")
end
local profile = profile_res[1]

local channel_sql = string.format("SELECT id, base_currency, status FROM channels WHERE id = %d", channel_id)
local channel_res = db:query(channel_sql)
if not channel_res or not channel_res[1] then
    return_error(500, "Channel not found")
end
local channel = channel_res[1]

-- p_app 생성
local p_app_res = create_p_app(db, data.p_app_code, data.granted_abilities, channel_id)
if not p_app_res or not p_app_res[1] then
    return_error(500, "Failed to create p_app")
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

local payload = {
    aud = "publ",
    exp = ngx.time() + 3600,
    iat = ngx.time(),
    iss = "publ",
    jti = jti,
    nbf = ngx.time() - 1,
    sub = user.type .. ":" .. tostring(user.id),
    typ = "access",
    seller = {
        distinctId = user.distinct_id,
        email = data.email,  -- 사용자가 제공한 이메일 정보
        id = user.id,
        identity = "IDENTITY:" .. user.type .. ":" .. user.id,
        isGlobalSeller = user.is_global_seller,
        mainProfile = {
            id = profile.id,
            nickname = profile.nickname
        },
        operatingChannels = {
            [tostring(channel.id)] = {
                baseCurrency = channel.base_currency,
                installedPApps = installedPApps,
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

local token, err = jwt.sign(payload)
if not token then
    return_error(500, "Failed to create JWT: " .. (err or "unknown error"))
end

-- 성공 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "Channel created successfully",
    channel_id = channel_id,
    pAppCode = data.p_app_code,
    grantedAbilities = data.granted_abilities,
    token = token
}))
