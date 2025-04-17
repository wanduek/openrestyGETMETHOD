local postgre = require "postgre"
local cjson = require "cjson.safe"
local jwt_util = require "jwt"  -- 위에 말한 jwt.lua

ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)

if not data or not data.email or not data.password then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(cjson.encode({ error = "Email and password required" }))
    return
end

-- DB 연결
local db, err = postgre.new()
if not db then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to connect to database" }))
    return
end

-- 예시: 사용자 이메일 중복 체크 & 삽입
local res, err = db:query(string.format(
    "SELECT * FROM users WHERE email = %s", ngx.quote_sql_str(data.email)
))
if res and #res > 0 then
    ngx.status = ngx.HTTP_CONFLICT
    ngx.say(cjson.encode({ error = "Email already exists" }))
    return
end

-- 사용자 정보 삽입 
local insert_sql = string.format(
    "INSERT INTO users (email, password) VALUES (%s, %s) RETURNING id",
    ngx.quote_sql_str(data.email),
    ngx.quote_sql_str(data.password)
)
local insert_res, insert_err = db:query(insert_sql)

if not insert_res or not insert_res[1] then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to insert user" }))
    return
end

local user_id = insert_res[1].id

-- JWT 생성
local token = jwt_util.sign({
    sub = tostring(user_id),
    email = data.email,
    iat = ngx.time(),
    exp = ngx.time() + 3600 -- 1시간 유효
})

-- 응답
ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode({
    message = "User registered successfully",
    token = token
}))
