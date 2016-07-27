require "string"
require "table"
local bit = require("bit")
local cjson = require("cjson")
local jwt = require("resty.jwt")
local jwt_secret = ngx.var.jwt_secret
local jwt_auth_site = ngx.var.jwt_auth_site
local jwt_access_flags = ngx.var.jwt_access_flags
local jwt_cookie_domain = ngx.var.jwt_cookie_domain
local jwt_cookie_name = ngx.var.jwt_cookie_name
local jwt_max_token_age_in_seconds = tonumber(ngx.var.jwt_max_token_age_in_seconds)
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

------------------------------------------------------------------------------
-- @function _replace()
--
-- Doing a direct string replace in LUA with dynamic text requires escaping
-- all the special lua chars.  Found the solution, implemented below, here:
-- http://stackoverflow.com/a/29379912
------------------------------------------------------------------------------
local function _replace(str, what, with)
  what = string.gsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") -- escape pattern
  with = string.gsub(with, "[%%]", "%%%%") -- escape replacement
  return string.gsub(str, what, with)
end

------------------------------------------------------------------------------
-- @function _sendUserToLogin()
--
-- Build the appropriate URL based on the calling service' "auth_site"
-- setting.  Then redirect the user to the "auth_site".  This function
-- will be called anywhere a JWT token fails to meet the criteria to
-- allow the user to proceed
------------------------------------------------------------------------------
local _sendUserToLogin = function()
  local redirectUrl = ngx.var.request_uri
  redirectUrl = _replace(redirectUrl, ngx.var.public_url, jwt_auth_site)
  ngx.req.set_header('X-Starphleet-Redirect', "true");
  ngx.req.set_header('X-Starphleet-OriginalUrl', ngx.var.request_uri);
  ngx.req.set_header('X-Starphleet-Authentic', ngx.var.authentic_token);
  return ngx.exec(redirectUrl)
end

------------------------------------------------------------------------------
-- @function _getAuthorizationHeader()
--
-- Return the body of the Authorization header after stripping out
-- any fragments of "Bearer".  The resulting string will either be
-- the JWT token or an empty string of Authorization wasn't passed
------------------------------------------------------------------------------
local _getAuthorizationHeader = function()
  if headers["Authorization"] then
    return headers["Authorization"]:gsub("Bearer ","")
  end

  return ""
end

------------------------------------------------------------------------------
-- @function _resetHeaders(token)
--
-- Pass the results of "resty:verify" to this method to reset any "jwt-*"
-- headers to match the "payload" portion of the jwt token.
--
-- The headers will be available to apps like this:
--   jwt-iat: $token.payload.iat
--   jwt-exp: $token.payload.exp
--   jwt-roles: $token.payload.roles
--   ...etc
--
-- The first iteration deletes anything starting with "jwt-".  The second
-- loop re-maps the payload to headers
------------------------------------------------------------------------------
local _resetHeaders = function(token)
  for k,v in pairs(ngx.req.get_headers()) do
    if (string.sub(k,1,4) == 'jwt-') then
      ngx.req.set_header(k,nil)
    end
  end
  for k,v in pairs(token.payload) do
    ngx.req.set_header("jwt-" .. k,cjson.encode(v))
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
--   * Token is not older than the max age configured
--   * Must not be expired
------------------------------------------------------------------------------
local _isValidToken = function(token)
  if token["verified"] and
    type(token["payload"]) == "table" and
    token.payload.iat and
    token.payload.exp and
    type(token.payload.iat) == "number" and
    type(token.payload.exp) == "number" and
    ngx.time() - token.payload.iat <= jwt_max_token_age_in_seconds then
    --
    return true
  end
  --
  return false
end

-- *****************************************************************************
-- * Main
-- *****************************************************************************

------------------------------------------------------------------------------
-- Decode each of the token types.  We handle things slightly different
-- based on how the caller sent us the JWT token.  From a high level:
--    * Passing JWT via URL allows custom expiration times but
--      confines your JWT token to a specific service.
--    * After a URL token authenticates, a cookie is returned
--      populated assigned an experation set in the orders.
--    * The "cookie" JWT token can be passed via the "Authorization"
--      header to REST api's.  These kinds of requests result in a "401"
--      if the JWT token is not valid or expires instead of redirecting
--      to the login app
------------------------------------------------------------------------------
local authorizationBearerString = _getAuthorizationHeader()
local verified_url_token = jwt:verify(jwt_secret, ngx.var.arg_jwt, 0)
local verified_cookie_token = jwt:verify(jwt_secret, ngx.var["cookie_" .. jwt_cookie_name], 0)
local verified_bearer_token = jwt:verify(jwt_secret, authorizationBearerString, 0)

------------------------------------------------------------------------------
-- JWT tokens passed via the URL have priority over a JWT token
-- set via the cookie.  The JWT token passed in the URL must
-- have the claim "svc" binding the URL based token to only one
-- service.  An app can use the resulting cookie (set below)
-- for calls to other services and/or to refresh the session
-- associated with the JWT token that was originally passed in the URL.
-- Below - We associate the 'token' with whichever token is valid first
------------------------------------------------------------------------------
local token = nil
local redirect = nil
if _isValidToken(verified_url_token) then
  token = verified_url_token
  redirect = ngx.var.request_uri
  redirect = redirect:gsub([[jwt=[^&]*&?]],"")
  redirect = redirect:gsub([[%?$]],"")
  redirect = redirect:gsub([[&$]],"")
elseif _isValidToken(verified_bearer_token) then
  token = verified_bearer_token
elseif _isValidToken(verified_cookie_token) then
  token = verified_cookie_token
end

------------------------------------------------------------------------------
-- Access Flags:
-- If the valid token contains 'af' (access flags) we will limit
-- the response at a service level based on these flags.
------------------------------------------------------------------------------

if token
  and token.payload
  and token.payload.af
  and jwt_access_flags
  and jwt_access_flags ~= ""
  and bit.band(token.payload.af, jwt_access_flags) == 0 then
  return ngx.exit(403)
end

------------------------------------------------------------------------------
-- If the above process results in a valid token then we set the cookie
-- with the appropriate JWT payload
------------------------------------------------------------------------------
if (token) then

  ------------------------------------------------------------------------------
  -- Refresh the expire time
  ------------------------------------------------------------------------------
  token.payload.exp = ngx.time() + jwt_expiration_in_seconds

  ------------------------------------------------------------------------------
  -- Create a new jwt token
  ------------------------------------------------------------------------------
  local signedJwtToken = jwt:sign(jwt_secret, { payload=token.payload, header=token.header } )


  ------------------------------------------------------------------------------
  -- LUA does not support string appends OR ternary operations
  -- Even still, for now, I'm keeping the format for easy
  -- manipulations.  Dynamically build a cookie string to assign
  -- the JWT session token to the request
  ------------------------------------------------------------------------------
  local cookieString = ""
  cookieString = cookieString .. (signedJwtToken and jwt_cookie_name .. "=" .. signedJwtToken or '')
  cookieString = cookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
  cookieString = cookieString .. '; Path=/'
  cookieString = cookieString .. (jwt_expiration_in_seconds and '; Expires=' .. ngx.cookie_time(token.payload.exp) or '')
  ngx.header['Set-Cookie'] = cookieString

  if redirect then
    return ngx.redirect(redirect)
  end

  -- ** Reset any headers starting with jwt- with fields in our payload ** --
  return _resetHeaders(token)
end

  ------------------------------------------------------------------------------
  -- We get to here if none of the tokens succeeded in being valid.
  -- Before we redirect the user to the login page we check to see
  -- if the request was made using the Authorization header.  If it was
  -- made using the Auth header, this was an API call and we set status
  -- to 401 letting the API call know it needs to re-authenticate.
  ------------------------------------------------------------------------------
if authorizationBearerString ~= "" then
  return ngx.exit(401)
end

  ------------------------------------------------------------------------------
  -- If we get here, no condition existed to verify a JWT token sent to us
  -- and thus, no matter what, we redirect the user to the login page
  ------------------------------------------------------------------------------
_sendUserToLogin()
