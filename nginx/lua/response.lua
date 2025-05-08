local cjson = require "cjson.safe"

local _M = {}

-- 성공 응답
function _M.success(data)
    ngx.status = 200
    ngx.say(cjson.encode(data))
    return ngx.exit(200)
end

-- 생성 응답
function _M.created(data)
    ngx.status = 201
    ngx.say(cjson.encode(data))
    return ngx.exit(201)
end

-- 권한없음 응답
function _M.Unauthorized(message)
    ngx.status = 401
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(401)
end

-- 접근 제한 응답
function _M.forbidden(message)
    ngx.status = 403
    ngx.say(cjson.encdoe({ error = message }))
    return ngx.exit(403)
end

-- 찾을 수 없음 응답
function _M.not_found(message)
    ngx.status = 404
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(404)
end

-- 메서드가 올바르지 않음 응답
function _M.method_not_allowed(message)
    ngx.status = 405
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(405)
end

-- 중복 응답
function _M.conflict(message)
    ngx.status = 409
    ngx.say(cjson.encode({ error = messasge }))
    return ngx.exit(409)
end

-- 내부 서버 오류 응답
function _M.internal_server_error(message)
    ngx.status = 500
    ngx.say(cjson.encode({ error = message }))
    return ngx.exit(500)
end

return _M