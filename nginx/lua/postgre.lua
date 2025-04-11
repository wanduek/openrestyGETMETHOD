local pg = require "resty.postgres"

local _M = {}

function _M.new()
    local db, err = pg:new()
    if not db then
        return nil, "Failed to create postgres object"
    end

    db:set_timeout(1000)

    local ok, err = db:connect({
        host = os.getenv("DB_HOST"),
        port = tonumber(os.getenv("DB_PORT")),
        database = os.getenv("DB_NAME"),
        user = os.getenv("DB_USER"),
        password = os.getenv("DB_PASSWORD")
    })

    if not ok then
        return nil, "Failed to connect postgres: " .. err
    end

    return db, nil
end

return _M
