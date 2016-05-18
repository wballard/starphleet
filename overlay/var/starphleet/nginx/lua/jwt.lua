require "string"
require "table"
local jwt = require "resty.jwt"
local jwt_secret = ngx.var.jwt_secret
local jwt_auth_site = ngx.var.jwt_auth_site
local jwt_cookie_domain = ngx.var.jwt_cookie_domain
local jwt_expiration_in_seconds = tonumber(ngx.var.jwt_expiration_in_seconds)
local headers = ngx.req.get_headers()

-- *****************************************************************************
-- * Guards
-- *****************************************************************************

if not jwt_secret or jwt_secret == "" then
  ngx.log(ngx.ERR, "Error processing jwt authentication. Missing JWT_SECRET configuration value")
  return ngx.exit(500)
end

-- *****************************************************************************
-- * Helper Methods
-- *****************************************************************************

-- TODO: Documentation
local _sendUserToLogin = function()
  local full_request_uri = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
  return ngx.redirect(jwt_auth_site .. "?target=" .. ngx.escape_uri(full_request_uri))
end

-- TODO: Documentation
local _getAuthorizationHeader = function()
  if headers["Authorization"] then
    return headers["Authorization"]:gsub("Bearer ","")
  end

  return ""
end

-- TODO: Documentation
local _resetHeaders = function(token)
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,4) == 'jwt-') then
      ngx.header[k] = nil
    end
  end
  for k,v in pairs(token.payload) do
    ngx.header["jwt-" .. k] = v
  end
end

------------------------------------------------------------------------------
-- @function _isValidToken(token)
--
-- Pass the results of "resty:verify" to this method to determine if result
-- meets the criteria to proceed with the request.
--
-- To Be Valid:
--   * Must verify and decode (handled by resty)
--   * Must include a payload
--   * Must include the reserved 'iat'/'exp' jwt claims
--   * iat and exp fields must be valid numbers
--   * Must not be expired
------------------------------------------------------------------------------
local _isValidToken = function(tokenType, token)
  if token["verified"] and
    type(token["payload"]) == "table" and
    token.payload.iat and
    token.payload.exp and
    type(token.payload.iat) == "number" and
    type(token.payload.exp) == "number" and
    token.payload.exp >= ngx.time() then
      -- At this point the token itself has all the items
      -- we expect.  Now we need to validate the various
      -- conditions in which we may receive a token
      --   * If token was passed via URL:
      --     - Must contain "svc" claim
      --     - "svc" claim must match the requested service
      --     - This is required to allow URL tokens to override
      --       expiration settings but be locked to a specific
      --       service
      --   * If token was passed via Cookie or Bearer
      --     - Can NOT contain "svc"
      --     - Tokens expiration cant have been set above "max"
      --     - Tokens issued time cannot exceed the services configured
      --       expiration time
      if tokenType == "url" then
        ngx.log(ngx.ERR,"URL Token - ",token.payload.svc == ngx.var.public_url)
        return token.payload.svc == ngx.var.public_url
      end
      if token.payload.svc then
        ngx.log(ngx.ERR,"Any Other Token With SVC",ngx.time())
        return false
      end
      if ngx.time() - token.payload.iat <= jwt_expiration_in_seconds and
        token.payload.exp - token.payload.iat <= jwt_max_expiration_duration then
        ngx.log(ngx.ERR,"Expire Times Okay")
        return true
      end
  end
  ngx.log(ngx.ERR,"Return Catchall")
  return false
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
local buffer = ""
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    buffer = buffer .. string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      -- buffer = buffer .. formatting
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      buffer = buffer .. tostring(v) .. " "
    else
      buffer = buffer .. v .. " "
    end
  end
  return buffer
end

-- TODO: Documentation
local authorizationBearerString = _getAuthorizationHeader()
local verified_url_token = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
local verified_cookie_token = jwt:verify(jwt_secret, ngx.var.cookie_jwt, 0)
local verified_bearer_token = jwt:verify(jwt_secret, authorizationBearerString, 0)

buffer = ""
ngx.log(ngx.ERR,"Tokens - url - ",tprint(verified_url_token))
buffer = ""
ngx.log(ngx.ERR,"Tokens - cookie - ",tprint(verified_cookie_token))
buffer = ""
ngx.log(ngx.ERR,"Tokens - header - ",authorizationBearerString, tprint(verified_bearer_token))


if _isValidToken("bearer", verified_bearer_token) then
  ngx.log(ngx.ERR,"Bearer Success")
  return _resetHeaders(verified_bearer_token)
end

local token = nil
if _isValidToken("url", verified_url_token) then
  token = verified_url_token
elseif _isValidToken("cookie", verified_cookie_token) then
  token = verified_cookie_token
end

if (token) then

  token.payload.exp = ngx.time() + jwt_expiration_in_seconds

  local signedJwtToken = jwt:sign(jwt_secret, { payload=token.payload, header=token.header } )

  local cookieString = ""
  cookieString = cookieString .. (signedJwtToken and "jwt=" .. signedJwtToken or '')
  cookieString = cookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
  cookieString = cookieString .. (ngx.var.public_url and '; Path=' .. ngx.var.public_url or '')
  cookieString = cookieString .. (jwt_expiration_in_seconds and '; Expires=' .. ngx.cookie_time(ngx.time() + jwt_expiration_in_seconds) or '')
  -- and we create the cookie, here the interesting part is the expiration which is the JWT_EXPIRATION_IN_SECONDS from THE ORDERS
  -- plus the leeway value from the context which gives us a cookie that can expire AFTER the expiration of the JWT token it contains
  -- thus we can continue to make decisions based on the JWT token last issued instead of having no cookie at all when the token expires.
  -- This behavior is acceptable because JWT token we use to get here is VALID it's only the exp value within that has been exceeded, and
  -- given our leeway behavior we can go ahead and re-issue a token with a new expiration date (apply the leeway).
  ngx.header['Set-Cookie'] = cookieString
  return _resetHeaders(token)
end

if authorizationBearerString ~= "" then
  return ngx.exit(401)
end

_sendUserToLogin()
