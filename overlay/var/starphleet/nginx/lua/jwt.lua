require "string"
require "table"
local cjson = require "cjson"
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
  redirectUrl = redirectUrl:gsub(ngx.var.public_url, jwt_auth_site)
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
      if tokenType == "url" and
        token.payload.svc == ngx.var.public_url then
        return true
      end
      -- Now we are testing the service level configurable expirations
      -- since the token sent to us must be either a Auth Bearer (REST)
      -- or Cookie based JWT token
      if ngx.time() - token.payload.iat <= jwt_expiration_in_seconds then -- and
        -- token.payload.exp - token.payload.iat >= jwt_max_expiration_duration_in_seconds then
        return true
      end
  end
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
local verified_cookie_token = jwt:verify(jwt_secret, ngx.var.cookie_jwt, 0)
local verified_bearer_token = jwt:verify(jwt_secret, authorizationBearerString, 0)

------------------------------------------------------------------------------
-- If the token was passed via the "Authorization: Bearer" header
-- all we do is validate the token and let the request proceed.
-- a cookie does not get refreshed or generated for these requests
------------------------------------------------------------------------------
if _isValidToken("bearer", verified_bearer_token) then
  -- ** Reset any headers starting with jwt- with fields in our payload ** --
  return _resetHeaders(verified_bearer_token)
end

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
if _isValidToken("url", verified_url_token) then
  token = verified_url_token
  redirect = ngx.var.request_uri
  redirect = redirect:gsub([[jwt=[^&]*&?]],"")
  redirect = redirect:gsub([[%?$]],"")
  redirect = redirect:gsub([[&$]],"")
elseif _isValidToken("cookie", verified_cookie_token) then
  token = verified_cookie_token
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
  -- If the "svc" claim exists we purge it and then rebuild the JWT token
  -- without the svc claim to be assigned to the cookie below
  ------------------------------------------------------------------------------
  token.payload["svc"] = nil
  local signedJwtToken = jwt:sign(jwt_secret, { payload=token.payload, header=token.header } )


  ------------------------------------------------------------------------------
  -- LUA does not support string appends OR ternary operations
  -- Even still, for now, I'm keeping the format for easy
  -- manipulations.  Dynamically build a cookie string to assign
  -- the JWT session token to the request
  ------------------------------------------------------------------------------
  local cookieString = ""
  cookieString = cookieString .. (signedJwtToken and "jwt=" .. signedJwtToken or '')
  cookieString = cookieString .. (jwt_cookie_domain and '; Domain=' .. jwt_cookie_domain or '')
  cookieString = cookieString .. (ngx.var.public_url and '; Path=' .. ngx.var.public_url or '')
  cookieString = cookieString .. (jwt_expiration_in_seconds and '; Expires=' .. ngx.cookie_time(token.payload.exp) or '')
  ngx.header['Set-Cookie'] = cookieString
  -- ** Reset any headers starting with jwt- with fields in our payload ** --

  if redirect then
    return ngx.redirect(redirect)
  end

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
