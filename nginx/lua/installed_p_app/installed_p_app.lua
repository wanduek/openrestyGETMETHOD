local postgre = require "db.postgre"
local jwt = require "middleware.jwt"
local cjson = require "cjson.safe"
local lua_query = require "lua_query"
local response = require "response"
local payload_builder = require "middleware.payload_build"

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
local user = lua_query.get_user_by_id(db, user_id)

-- seller의 main_profile 조회
local main_profile = lua_query.get_main_profile(db, user_id)

-- channel 조회
local channel = lua_query.get_channel_by_id(db, channel_id)

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

-- 커넥션 풀에 반납
postgre.keepalive(db)

local payload = payload_builder.build({
    user = user, 
    main_profile = main_profile, 
    channel = channel, 
    installedPApps = installedPApps,
    channel_id = channel_id
})

local token = jwt.sign(payload)

local success_data = {
    message = "Channel created successfully",
    channel_id = channel_id,
    pAppCode = data.p_app_code,
    grantedAbilities = data.granted_abilities,
    token = token
}
-- 성공 응답
response.success(success_data)
