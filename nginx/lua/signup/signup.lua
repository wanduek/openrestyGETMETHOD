local postgre = require "db.postgre"
local cjson = require "cjson.safe"
local jwt = require "middleware.jwt"
local response = require "response"
local payload_builder = require "middleware.payload_build"

-- 요청 메서드 확인
if ngx.req.get_method() ~= "POST" then
    return response.method_not_allowed("Method not allowed")
end

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)
if not data or not data.email or not data.password then
    return response.bad_request("Email and password required")
end

-- DB 연결
local db = postgre.new()
if not db then
    return response.internal_server_error("Failed to connect to database")
end

-- 예시: 사용자 이메일 중복 체크 & 삽입
local res = db:query(string.format(
    "SELECT * FROM users WHERE email = %s", ngx.quote_sql_str(data.email)
))
if res and #res > 0 then
    return response.conflict("Email already exists")
end

-- 사용자 정보 삽입
local insert_sql = string.format(
    "INSERT INTO users (email, password, role, type) VALUES (%s, %s, %s, %s) RETURNING id, distinct_id, status, is_global_seller, email, role, type",
    ngx.quote_sql_str(data.email),
    ngx.quote_sql_str(data.password),
    ngx.quote_sql_str(data.role),
    ngx.quote_sql_str(data.type)

)
local insert_res = db:query(insert_sql)

if not insert_res or not insert_res[1] or not insert_res[1].id then
    return resposne.internal_server_error("Failed to insert user")
end

local user = insert_res[1]

-- main_profiles에 insert
local insert_profile_sql = string.format([[
    INSERT INTO main_profiles (user_id, nickname)
    VALUES (%d, %s) RETURNING id, nickname
]], user.id, ngx.quote_sql_str(data.nickname))

local main_profile_res = db:query(insert_profile_sql)

local main_profile = main_profile_res[1]

-- 커넥션 풀에 반납
postgre.keepalive(db)

local payload = payload_builder.build({
    user = user,
    main_profile = main_profile
})

local token = jwt.sign(payload)

local success_data = {
    message = "User registered successfully",
    token = token
}
-- 성공 응답
response.success(success_data)
