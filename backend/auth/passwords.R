# backend/auth/passwords.R
# Password hashing using sodium (Argon2id)

library(sodium)

hash_password <- function(password) {
  sodium::password_store(password)
}

verify_password <- function(password, hash) {
  tryCatch(
    sodium::password_verify(hash, password),
    error = function(e) FALSE
  )
}
