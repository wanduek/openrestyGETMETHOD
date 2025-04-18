local postgre = require "db.postgre"
local cjson = require "cjson"
local utils = require "utils"
local redis = require "redis"

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

-- 캐시 키 생성
local cache_key = "resourceTransportRecords:" .. page .. ":" .. limit

-- Redis에서 캐시 조회
local cached_data, err = redis.get(cache_key)
if cached_data then
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        data = cjson.decode(cached_data)
    }))
    return 
end

-- PostgreSQL 연결
local db, err = postgre.new()
if not db then
    ngx.status = 500
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = "Failed to create database object"
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

local camel_records = utils.rows_to_camel(records)

-- 커넥션 풀에 반납
postgre.keepalive(db)

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

-- Redis에 캐시 저장 (TTL 60초)
local success, err = redis.set(cache_key, cjson.encode(response), 60)
if not success then
    ngx.log(ngx.ERR, "Failed to cache data in redis: ", err)
end

-- JSON 응답 반환
ngx.header["Content-Type"] = "application/json"
ngx.say(cjson.encode(response))
