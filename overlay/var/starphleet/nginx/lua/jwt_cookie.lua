-- grab the already parsed and verified jwt_obj from the ngx per request cache
local ctx = ngx.ctx
local jwt_obj = ctx.jwt_obj
local service_public_url = ngx.var.public_url

if jwt_obj and jwt_obj["verified"] then
  local jwt = require "resty.jwt"
  local jwt_secret = ngx.var.jwt_secret
  local jwt_cookie_domain = ngx.var.jwt_cookie_domain
  local token_duration = ngx.var.jwt_expiration
  local payload = jwt_obj["payload"]
  local leeway = ctx.leeway
  -- if the token is verified but has expired, it must be within the leeway, so reissue a new token
  -- ctx.session is true iff we got the token from a cookie (rather than the querystring)
  --
  -- if we have NO ctx.session OR we have a payload decoded and it has an 'exp' parameter that is LESS than
  -- the current time ( i.e. the token is expired ) the we'll do our work in the if below. The end restult is that
  -- we will issue a cookie if the request included a token on the querystring or the token itself is from a cookie and
  -- indicates that it is expired but is otherwise valid.
  if not ctx.session or (payload["exp"] and type(payload["exp"]) == "number" and payload["exp"] < ngx.now() ) then
    -- if your jwt is from querystring, we give you the full JWT_EXPIRATION_IN_SECONDS as specified in the ORDERS!
    -- which is likely different from anything specified in the token.
    -- if it's from a cookie and has expired within leeway, we give you another leeway
    local duration = ctx.session and leeway or token_duration
    -- so, we create a new expiration time starting now and lasting the value of duration ( in seconds )
    local exp = ngx.time() + duration
    payload["exp"] = exp
    -- our expiration becomes part of the token we are going to put in the cookie replacing the expiration that may already b
    -- present
    local jwt_cookie = jwt:sign(jwt_secret, { payload=payload, header=jwt_obj.header } )
    -- get the cookie domain if configured
    local cookie_domain = not jwt_cookie_domain and '' or '; Domain=' .. jwt_cookie_domain
    -- and we create the cookie, here the interesting part is the expiration which is the JWT_EXPIRATION_IN_SECONDS from THE ORDERS
    -- plus the leeway value from the context which gives us a cookie that can expire AFTER the expiration of the JWT token it contains
    -- thus we can continue to make decisions based on the JWT token last issued instead of having no cookie at all when the token expires.
    ngx.header['Set-Cookie'] = "jwt=" .. jwt_cookie .. cookie_domain .. "; Path=" .. service_public_url .. "; Expires=" .. ngx.cookie_time(ngx.time() + token_duration + leeway)
  end
end
