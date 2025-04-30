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
local function create_channel_user_profile(db, age, birth_year, distinct_id, certified_age, gender, image_src, is_featured, nickname)
    local sql = string.format(
        "INSERT INTO profiles ( age, birth_year, certified_age, distinct_id, gender, image_src, is_featured, nickname) " ..
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %d) RETURNING id, distinct_id",
        ngx.quote_sql_str(age),
        ngx.quote_sql_str(birth_year),
        ngx.quote_sql_str(certified_age),
        ngx.quote_sql_str(gender),
        ngx.quote_sql_str(image_src),
        ngx.quote_sql_str(is_featured),
        ngx.quote_sql_str(nickname),
        distinct_id
    )
    local res = db:query(sql)
    return res
end

-- 요청 본문 파싱
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.age or not data.birth_year or not data.certified_age or not data.gender or not data.image_src or not data.is_featured or not data.nickname then
    return_error(ngx.HTTP_BAD_REQUEST, "profile datas are required")
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
local channel_user_profile = profile_res[1]

local channel_sql = string.format("SELECT id, base_currency, status FROM channels WHERE id = %d", channel_id)
local channel_res = db:query(channel_sql)
if not channel_res or not channel_res[1] then
    return_error(500, "Channel not found")
end
local channel = channel_res[1]

-- profile 생성
local profile_res = create_channel_user_profile(
db, 
data.age, 
data.birth_year, 
data.certified_age, 
profile.distinct_id, 
data.gender, 
data.is_featured, 
data.nickname
)
if not profile_res or not profile_res[1] then
    return_error(500, "Failed to create profile")
end

local channel_members = string.format("INSERT INTO channel_memberships (channel_id, profile_id) VALUES (%d, %d) RETURNING channel_id, profile_id", 
channel_id, 
profile.id
)
local channel_member_res = db:query(channel_members)
if not channel_member_res then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Fail to create channel membership"}))
    return
end

-- profile 구성
local app = profile_res[1]
local profile = {
        age = app.age,
        birthYear = app.birth_year,
        certifiedAge = app.certified_age,
        distinctId = app.distinct_id,
        gender = app.gender,
        id = app.id,
        imageSrc = app.image_src,
        isFeatured = app.is_featured,
        nickname = app.nickname
    }

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
                -- installedPApps = installedPApps,
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
