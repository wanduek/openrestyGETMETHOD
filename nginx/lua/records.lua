local pg = require "resty.postgres"
local cjson = require "cjson"
local utils = require "utils"

-- 요청 메서드 확인
if ngx.req.get_method() ~= "GET" then
    ngx.status = 405
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Method not allowed"
    }))
    return
end

-- 페이지네이션 파라미터 가져오기
local args = ngx.req.get_uri_args()
local page = tonumber(args.page) or 1
local limit = tonumber(args.limit) or 10
local offset = (page - 1) * limit

-- PostgreSQL 연결
local db, err = pg:new()
if not db then
    ngx.status = 500
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Failed to create database object"
    }))
    return
end

db:set_timeout(1000) -- 1초 타임아웃
ngx.log(ngx.ERR, "DB HOST => ", os.getenv("DB_HOST"))

-- 데이터베이스 접속
local ok, err = db:connect({
    host = os.getenv("DB_HOST"),
    port = tonumber(os.getenv("DB_PORT")),
    database = os.getenv("DB_NAME"),
    user = os.getenv("DB_USER"),
    password = os.getenv("DB_PASSWORD")
})

if not ok then
    ngx.status = 500
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "database connection er: " .. err
    }))
    return
end

-- 총 레코드 수 조회
local count_sql = "SELECT COUNT(*) as total FROM resourceTransportRecords"
local res, err = db:query(count_sql)
if not res then
    ngx.status = 500
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Failed to query total count: " .. (err or "unknown error")
    }))
    return
end

local total = tonumber(res[1].total) or 0


local sql = [[
    SELECT
        *
    FROM
        resourceTransportRecords
    LIMIT ]] .. limit .. " OFFSET " .. offset

local records, err = db:query(sql)
if not records then
    ngx.status = 500
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Failed to query records: " .. (err or "unknown error")
    }))
    return
end

-- DB 연결 반환 (커넥션 풀에)
local ok, err = db:set_keepalive(10000, 100)
if not ok then
    ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
end

local camel_records = utils.rows_to_camel(records)
-- 응답 구성
local response = {
    data = {
        pagnation = {
            page = page,
            total = total,
            limit = limit
        },
        records = camel_records
    }
}

-- JSON 응답 반환
ngx.header["Content-Type"] = "application/json"
ngx.say(cjson.encode(response))
