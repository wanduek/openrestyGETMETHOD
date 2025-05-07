local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"
local lua_query = require "lua_query"

-- profiles 생성
local function create_channel_user_profile(db, data)
    local function safe_quote(value)
        if value == nil or value == "null" then
            return "NULL"
        else
            return ngx.quote_sql_str(value)
        end
    end

    local is_featured_sql = (data.is_featured == true or data.is_featured == "true") and "TRUE" or "FALSE"
    local sql = string.format(
        "INSERT INTO profiles ( age, birth_year, certified_age, gender, image_src, is_featured, nickname) " ..
        "VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id, distinct_id",
        safe_quote(data.age),
        safe_quote(data.birth_year),
        safe_quote(data.certified_age),
        safe_quote(data.gender),
        safe_quote(data.image_src),
        is_featured_sql,
        safe_quote(data.nickname)
    )
    local res = db:query(sql)

    return res[1]
end

-- 요청 본문 파싱
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

local required_profile = { "age", "birth_year", "certified_age", "gender", "image_src", "is_featured", "nickname"}
for _, field in ipairs(required_profile) do
    if not data[field] then 
        ngx.status = 400
        ngx.say(cjson.encode({ error = field .. "is required"}))
        return
    end 
end


-- 사용자 정보 추출
local user_id = ngx.ctx.user_id

-- 채널 정보 추출
local channel_id = ngx.ctx.channel_id

-- DB 연결
local db = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to DB"}))
    return
end

-- 사용자, 프로필, 채널 정보 조회
local user, err = lua_query.get_user_by_id(db, user_id)
if not user then
    ngx.status = 404
    ngx.say(cjson.encode({ error = err }))
    return
end

-- seller 메인 프로필 조회
local main_profile, err = lua_query.get_main_profile(db, user_id)
if not main_profile then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "not found main profile" }))
    return
end

-- 채널 조회
local channel, err = lua_query.get_channel_by_id(db, channel_id)
if not channel then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "not foound channel"}))
    return
end

-- profile 생성 후 조회
local profile = create_channel_user_profile(
    db, data
)
if not profile then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to create profile" }))
    return
end

local profile_id = profile.id

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

local payload = jwt.sign{
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
            id = main_profile.id,
            nickname = main_profile.nickname
        },
        operatingChannels = {
            [tostring(channel_id)] = {
                baseCurrency = channel.base_currency,
                profile = {
                    id =profile.id,
                    nickname =  data.nickname,
                    age = data.age,
                    birthYear = data.birth_year,
                    certifiedAge = data.certified_age,
                    gender = data.gender,
                    imageSrc = profile.image_src,
                    isFeatured = profile.is_featured,
                    distinctId = profile.distinctId
                },
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
    sub = user.type .. ":" .. user_id,
    typ = "access",
}

-- 성공 응답
ngx.status = 200
ngx.say(cjson.encode({
    message = "profile created successfully",
    channel_id = channel_id,
    profile_id = profile.id,
    token = payload
}))
