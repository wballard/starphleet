-- grab the already parsed and verified jwt_obj from the ngx per request cache
local ctx = ngx.ctx
local jwt_obj = ctx.jwt_obj
local service_public_url = ngx.var.public_url

if jwt_obj and jwt_obj["verified"] then
  local jwt = require "resty.jwt"
  local jwt_secret = ngx.var.jwt_secret
  local jwt_cookie_domain = ngx.var.jwt_cookie_domain
  local jwt_global_cookie = ngx.var.jwt_global_cookie
  local token_duration = ngx.var.jwt_expiration
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
    if jwt_global_cookie == "true" then
      ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. cookie_domain .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + token_duration + leeway)
    else
      ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. cookie_domain .. "; Path=" .. service_public_url .. "; Expires=" .. ngx.cookie_time(ngx.time() + token_duration + leeway)
    end
  end
end
