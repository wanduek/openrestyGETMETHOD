local _M = {}
local jwt = require "middleware.jwt"

function _M.build_payload(user, profile, channel, installedPApps, channel_id)
    local jti = jwt.custom_random_jti(32)
    return {
        aud = "publ",
        exp = ngx.time() + 3600,
        iat = ngx.time(),
        iss = "publ",
        jti = jti,
        nbf = ngx.time() - 1,
        seller = {
            distinctId = user.distinct_id,
            email = user.email,
            id = user.id,
            identity = "IDENTITY:" .. user.type .. ":" .. user.id,
            isGlobalSeller = user.is_global_seller,
            mainProfile = {
                id = profile.id,
                nickname = profile.nickname
            },
            operatingChannels = {
                [tostring(channel_id)] = {
                    baseCurrency = channel.base_currency,
                    installedPApps = installedPApps,
                    profile = profile,
                    status = channel.status
                }
            },
            pAppAdditionalPermissions = {
                ["*"] = true
            },
            pAppPermission = { "*" },
            permissions = { "*" },
            role = user.role,
            status = user.status,
            type = user.type
        },
        sub = user.type .. ":" .. tostring(user.id),
        typ = "access",
    }
end

return _M
