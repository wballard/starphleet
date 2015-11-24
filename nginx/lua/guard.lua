require "os"
require "string"
require "table"
local jwt = require "resty.jwt"
local jwt_secret = os.getenv("JWT_SECRET")
local jwt_auth_site = os.getenv("JWT_AUTH_SITE")
local jwt_roles = {}
local role_authorized = false

if not jwt_auth_site then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_AUTH_SITE environment variable")
  return ngx.exit(500)
end

if not jwt_secret then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_SECRET environment variable")
  return ngx.exit(500)
end

function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

for role in string.gmatch(ngx.var.jwt_roles, '([^,]+)') do
  table.insert(jwt_roles,1,role)
end

local jwt_obj = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
if not jwt_obj["verified"] then
  jwt_obj = jwt:verify(jwt_secret, ngx.var.cookie_jwt, 0)
end

if type(jwt_obj.payload) == "table" then
  for user_role in string.gmatch(jwt_obj.payload.role, '([^,]+)') do
    for _,v in pairs(jwt_roles) do
      if trim(v) == trim(user_role) or trim(v) == '*' then
        role_authorized = true
        break
      end
    end
    if authenticated then break end
  end
end

if not jwt_obj["verified"] or not role_authorized then
  local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
  return ngx.redirect(jwt_auth_site .. "?target=" ..ngx.escape_uri(full_request_uri) )
else
  for k,v in pairs(jwt_obj.payload) do
    ngx.req.set_header("jwt-" .. k, v)
  end
end
