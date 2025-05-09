local jwt = require "middleware.jwt"

local _M = {}

function _M.build(args)
    local now = ngx.time()
    local jti = jwt.custom_random_jti(32)
    local user = args.user
    local channel_id = args.channel_id or 0
    local main_profile = args.main_profile or {}
    local channel = arg.channel or {}
    local profile = args.profile or {}
    local installedPApps = args.installedPApps or {}

    return {
        aud = "publ",
        exp = now + 3600,
        iat = now,
        iss = "publ",
        jti = jti,
        nbf = now - 1,
        sub = user.type .. ":" .. user.id,
        typ = "access",

        seller = {
            distinctId = user.distinct_id,
            email = user.email, 
            id = user.id,
            identity = "IDENTITY:" .. user.type .. ":" .. user.id,
            isGlobalSeller = user.is_global_seller,
            mainProfile = {
                id = main_profile.id,
                nickname = main_profile.nickname
            },
            operatingChannels = {
                [channel_id] = {
                    baseCurrency = channel.base_currency,
                    installedPApps = installedPApps,
                    profile = profile,
                    status = channel.status
                }
            },
            pAppAdditionalPermissions = { ["*"] = true },
            pAppPermission = { "*" },
            permissions = { "*" },
            role = user.role,
            status = user.status,
            type = user.type
        }
    }
end

return _M


