local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"
local lua_query = require "lua_query"
local response = require "response"
local payload_builder = require "middleware.payload_build"

-- profiles 생성
local function create_channel_user_profile(db, data)
    local function safe_quote(value)
        if value == nil then
            return response.internal_server_error("NULL")
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

    if not res or not res[1] then
        return response.internal_server_error('Failed to insert profile')
    end

    return res[1]
end

-- 요청 본문 파싱
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

local required_profile = { "age", "birth_year", "certified_age", "gender", "image_src", "is_featured", "nickname"}
for _, field in ipairs(required_profile) do
    if not data[field] then 
        return response.bad_request(field .. "is required")
    end 
end

-- 사용자 정보 추출
local user_id = ngx.ctx.user_id

-- 채널 정보 추출
local channel_id = ngx.ctx.channel_id

-- DB 연결
local db = postgre.new()

-- 사용자, 프로필, 채널 정보 조회
local user = lua_query.get_user_by_id(db, user_id)

-- seller 메인 프로필 조회
local main_profile = lua_query.get_main_profile(db, user_id)

-- 채널 조회
local channel = lua_query.get_channel_by_id(db, channel_id)

-- profile 생성 후 조회
local profile = create_channel_user_profile(
    db, data
)
if not profile then
    return resposne.internal_server_error("Failed to create profile")
end

local profile_id = profile.id

-- 채널 멤버십 생성
local channel_members = string.format("INSERT INTO channel_memberships (channel_id, profile_id) VALUES (%d, %d) RETURNING channel_id, profile_id", 
channel_id, 
profile_id
)

local channel_member_res = db:query(channel_members)
if not channel_member_res then
    return response.internal_server_error("Fail to create channel membership")
end

-- 커넥션 풀에 반납
postgre.keepalive(db)

local payload = payload_builder.build({
    user = user,
    main_profile = main_profile,
    channel = channel,
    channel_id = channel_id,
    profile = profile
})

local token = jwt.sign(payload)

local success_data = {
    message = "profile created successfully",
    channel_id = channel_id,
    profile_id = profile.id,
    token = token
}

-- 성공 응답
response.success(success_data)
