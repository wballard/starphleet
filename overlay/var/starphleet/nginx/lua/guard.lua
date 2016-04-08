require "string"
require "table"
local jwt = require "resty.jwt"
local jwt_secret = ngx.var.jwt_secret
local jwt_auth_site = ngx.var.jwt_auth_site
local jwt_expiration = tonumber(ngx.var.jwt_expiration)
local jwt_roles = {}
local role_authorized = false
local leeway = 900
local session = false

if not jwt_auth_site or jwt_auth_site == "" then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_AUTH_SITE configuration value")
  return ngx.exit(500)
end

if not jwt_secret or jwt_secret == "" then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_SECRET configuration value")
  return ngx.exit(500)
end

function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

for role in string.gmatch(ngx.var.jwt_roles, '([^,]+)') do
  table.insert(jwt_roles,1,role)
end

-- jwt:verify checks that the token can be decrypted,
-- is salted with the specified secret, and has not expired
-- ngx.var.arg_jwt = "jwt" querystring
local jwt_obj = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
if not jwt_obj["verified"] then
  -- ngx.var.cookie_jwt = "jwt" cookie
  -- we add leeway to allow us to reissue a token for one that has just expired
  jwt_obj = jwt:verify(jwt_secret, ngx.var.cookie_jwt, leeway)
  -- if we got jwt from a cookie, we're already in a session
  session = true
end

if jwt_obj["verified"] and type(jwt_obj.payload) == "table" then
  -- check that there are exp and iat properties
  -- and that iat is not more than 24 hours old
  if jwt_obj.payload.exp and jwt_obj.payload.iat and ngx.time() - jwt_obj.payload.iat <= jwt_expiration then
    -- check the roles the user has in the token against the roles
    -- specified in the .jwt file for the orders. Empty .jwt files
    -- get rewritten to "*" in the starphleet_publish script
    for user_role in string.gmatch(jwt_obj.payload.role, '([^,]+)') do
      for _,v in pairs(jwt_roles) do
        if trim(v) == trim(user_role) or trim(v) == '*' then
          role_authorized = true
          break
        end
      end
      if role_authorized then break end
    end
  end
end

if jwt_obj["verified"] and role_authorized then
  -- Loop over existing request headers and remove anything starting with 'jwt-'
  -- out of an abundance of security caution, so our jwt headers cannot be spoofed.
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,4) == 'jwt-') then
      ngx.req.set_header(k, nil)
    end
  end
  -- Set up our JWT properties as request headers
  for k,v in pairs(jwt_obj.payload) do
    ngx.req.set_header("jwt-" .. k, v)
  end
  local ctx = ngx.ctx
  ctx.jwt_obj = jwt_obj
  ctx.leeway = leeway
  if session then ctx.session = 'true' end
  ngx.ctx = ctx
else
  local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
  return ngx.redirect(jwt_auth_site .. "?target=" ..ngx.escape_uri(full_request_uri) )
end
