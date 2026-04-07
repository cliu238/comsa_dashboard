# backend/auth/tokens.R
# JWT token creation and verification using jose (HMAC-SHA256)

library(jose)

.jwt_secret <- NULL

get_jwt_secret <- function() {
  if (is.null(.jwt_secret)) {
    secret <- Sys.getenv("JWT_SECRET", "")
    if (nchar(secret) == 0) stop("JWT_SECRET environment variable not set")
    .jwt_secret <<- charToRaw(secret)
  }
  .jwt_secret
}

create_token <- function(user_id, email, role) {
  now <- as.numeric(Sys.time())
  payload <- jwt_claim(
    sub = user_id,
    email = email,
    role = role,
    iat = now,
    exp = now + 86400  # 24 hours
  )
  jwt_encode_hmac(payload, secret = get_jwt_secret())
}

verify_token <- function(token) {
  tryCatch(
    jwt_decode_hmac(token, secret = get_jwt_secret()),
    error = function(e) NULL
  )
}
