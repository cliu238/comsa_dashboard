# User database operations

source("auth/passwords.R")

save_user <- function(email, password, name = NULL, organization = NULL, role = "user") {
  conn <- get_db_connection()
  hash <- hash_password(password)

  query <- "
    INSERT INTO users (email, password_hash, name, organization, role)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING id, email, name, organization, role, is_active, created_at
  "

  result <- dbGetQuery(conn, query, params = list(email, hash, name, organization, role))
  as.list(result[1, ])
}

find_user_by_email <- function(email) {
  conn <- get_db_connection()

  query <- "SELECT * FROM users WHERE email = $1"
  result <- dbGetQuery(conn, query, params = list(email))

  if (nrow(result) == 0) return(NULL)
  as.list(result[1, ])
}

find_user_by_id <- function(user_id) {
  conn <- get_db_connection()

  query <- "SELECT id, email, name, organization, role, is_active, created_at, updated_at FROM users WHERE id = $1::uuid"
  result <- dbGetQuery(conn, query, params = list(user_id))

  if (nrow(result) == 0) return(NULL)
  as.list(result[1, ])
}

list_users <- function() {
  conn <- get_db_connection()

  query <- "
    SELECT u.id, u.email, u.name, u.organization, u.role, u.is_active, u.created_at,
           COUNT(j.id) as job_count
    FROM users u
    LEFT JOIN jobs j ON j.user_id = u.id
    GROUP BY u.id
    ORDER BY u.created_at DESC
  "

  dbGetQuery(conn, query)
}

update_user <- function(user_id, fields) {
  conn <- get_db_connection()
  allowed <- c("name", "organization", "role", "is_active")
  fields <- fields[names(fields) %in% allowed]

  if (length(fields) == 0) return(find_user_by_id(user_id))

  set_clauses <- paste0(names(fields), " = $", seq_along(fields) + 1)
  set_clauses <- c(set_clauses, "updated_at = NOW()")

  query <- sprintf(
    "UPDATE users SET %s WHERE id = $1::uuid RETURNING id, email, name, organization, role, is_active, created_at, updated_at",
    paste(set_clauses, collapse = ", ")
  )

  params <- c(list(user_id), unname(fields))
  result <- dbGetQuery(conn, query, params = params)

  if (nrow(result) == 0) return(NULL)
  as.list(result[1, ])
}
