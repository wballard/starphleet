-- grab the already parsed and verified jwt_obj from the ngx per request cache
local ctx = ngx.ctx
local jwt_obj = ctx.jwt_obj

if jwt_obj and jwt_obj["verified"] then
  require "os"
  local jwt = require "resty.jwt"
  local jwt_secret = os.getenv("JWT_SECRET")
  local jwt_cookie_domain = os.getenv("JWT_COOKIE_DOMAIN")
  local token_duration = os.getenv("JWT_EXPIRATION") or 3600
  local payload = jwt_obj["payload"]
  local leeway = ctx.leeway
  -- if the token is verified but has expired, it must be within the leeway, so reissue a new token
  -- ctx.session is true iff we got the token from a cookie (rather than the querystring)
  if not ctx.session or (payload["exp"] and type(payload["exp"]) == "number" and payload["exp"] < ngx.now() ) then
    -- if your jwt is from querystring, we give you the full JWT_EXPIRATION
    -- if it's from a cookie and has expired within leeway, we give you another leeway
    local duration = ctx.session and leeway or token_duration
    local exp = ngx.time() + duration
    payload["exp"] = exp
    local jwt_cookie = jwt:sign(jwt_secret, { payload=payload, header=jwt_obj.header } )
    local cookie_domain = not jwt_cookie_domain and '' or '; Domain=' .. jwt_cookie_domain
    ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. cookie_domain .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + token_duration + leeway)
  end
end
