require "os"
local jwt = require "resty.jwt"
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_cookie_domain = os.getenv("JWT_COOKIE_DOMAIN")
local token_duration = os.getenv("JWT_EXPIRATION") or 3600
-- grab the already parsed and verified jwt_obj from the ngx per request cache
local jwt_obj = ngx.ctx.jwt_obj

if jwt_obj and jwt_obj["verified"] then
  local exp = ngx.time() + token_duration
  local token = { payload=jwt_obj.payload, header= jwt_obj.header }
  token.payload.exp = exp
  local jwt_cookie = jwt:sign(jwt_secret,token)
  local cookie_domain = not jwt_cookie_domain and '' or '; Domain=' .. jwt_cookie_domain
  ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. cookie_domain .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + token_duration)
end
