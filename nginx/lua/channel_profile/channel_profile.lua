local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"

-- 헬퍼 함수: 에러 응답
local function return_error(status, msg)
    ngx.status = status
    ngx.say(cjson.encode({ error = msg }))
    return ngx.exit(status)
end

-- 헬퍼 함수: profiles 생성
local function create_channel_user_profile(db, age, birth_year, certified_age, gender, image_src, is_featured, nickname)
    local function safe_quote(value)
        if value == nil or value == "null" then
            return "NULL"
        else
            return ngx.quote_sql_str(value)
        end
    end
    local sql = string.format(
        "INSERT INTO profiles ( age, birth_year, certified_age, gender, image_src, is_featured, nickname) " ..
        "VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id, distinct_id",
        safe_quote(age),
        safe_quote(birth_year),
        safe_quote(certified_age),
        safe_quote(gender),
        safe_quote(image_src),
        tostring(is_featured == true or is_featured == "true" and "TRUE" or "FALSE"),
        safe_quote(nickname)
    )
    local res = db:query(sql)

    local distinct_id = res[1].distinct_id
    return res, distinct_id
end

-- 요청 본문 파싱
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.age or not data.birth_year or not data.certified_age or not data.gender or not data.image_src or not data.is_featured or not data.nickname then
    return_error(ngx.HTTP_BAD_REQUEST, "profile datas are required")
end

-- 사용자 정보 추출
local user_id = ngx.ctx.user_id
if not user_id then
    return_error(401, "Unauthorized: no user context")
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
local user_sql = string.format("SELECT id, email, role, type, distinct_id, is_global_seller, status FROM users WHERE id = %d", user_id)
local user_res = db:query(user_sql)
if not user_res or not user_res[1] then
    return_error(500, "User not found")
end
local user = user_res[1]

local profile_sql = string.format("SELECT id, nickname FROM main_profiles WHERE user_id = %d", user_id)
local main_profile_res = db:query(profile_sql)
if not main_profile_res or not main_profile_res[1] then
    return_error(500, "Main profile not found")
end

local main_profile_id = main_profile_res[1].id
local main_profile_nickname = main_profile_res[1].nickname

local channel_sql = string.format("SELECT id, base_currency, status FROM channels WHERE id = %d", channel_id)
local channel_res = db:query(channel_sql)
if not channel_res or not channel_res[1] then
    return_error(500, "Channel not found")
end
local channel = channel_res[1]

-- profile 생성 후 조회
local profile_res, distinct_id = create_channel_user_profile(
    db, 
    data.age, 
    data.birth_year, 
    data.certified_age,
    data.gender, 
    data.image_src, 
    data.is_featured, 
    data.nickname
)
if not profile_res or not profile_res[1] then
    return_error(500, "Failed to create profile")
end

-- 생성된 profile 다시 조회
local profile_id = profile_res[1].id
local get_profile_sql = string.format("SELECT * FROM profiles WHERE id = %d", profile_id)
local profile_query_res = db:query(get_profile_sql)
if not profile_query_res or not profile_query_res[1] then
    return_error(500, "Failed to fetch created profile")
end
local channel_user_profile = profile_query_res[1]

-- profile 구성
local profile = {
    id = channel_user_profile.id,
    nickname = channel_user_profile.nickname,
    age = data.age,
    birthYear = data.birth_year,
    certifiedAge = data.certified_age,
    gender = data.gender,
    imageSrc = channel_user_profile.image_src,
    isFeatured = channel_user_profile.is_featured,
    distinctId = distinct_id
}

-- 채널 멤버십 생성
local channel_members = string.format("INSERT INTO channel_memberships (channel_id, profile_id) VALUES (%d, %d) RETURNING channel_id, profile_id", 
channel_id, 
profile_id
)
local channel_member_res = db:query(channel_members)
if not channel_member_res then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Fail to create channel membership"}))
    return
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
        email = user.email,  -- 사용자가 제공한 이메일 정보
        id = user.id,
        identity = "IDENTITY:" .. user.type .. ":" .. user.id,
        isGlobalSeller = user.is_global_seller,
        mainProfile = {
            id = main_profile_id,
            nickname = main_profile_nickname
        },
        operatingChannels = {
            [tostring(channel.id)] = {
                baseCurrency = channel.base_currency,
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
    return_error(500, "Failed to create JWT: " .. (err or "unknown error"))
end

-- 성공 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "profile created successfully",
    channel_id = channel_id,
    profile_id = channel_member_res.profile_id,
    token = token
}))
