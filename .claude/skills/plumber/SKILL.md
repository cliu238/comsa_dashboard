---
name: plumber
description: R package for creating REST APIs with plumber framework
---

# Plumber Skill

R package for creating REST APIs by decorating R functions with special comments.

## When to Use This Skill

This skill should be triggered when:
- Creating REST APIs in R
- Working with plumber annotations (`#*` or `#'`)
- Setting up API endpoints (GET, POST, PUT, DELETE)
- Configuring serializers and parsers
- Deploying R APIs to production
- Adding filters, hooks, or middleware to R APIs

## Quick Reference

### Basic API Structure

```r
# plumber.R
#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg="") {
  list(msg = paste0("The message is: '", msg, "'"))
}

#* Return the sum of two numbers
#* @param a The first number
#* @param b The second number
#* @post /sum
function(a, b) {
  as.numeric(a) + as.numeric(b)
}
```

### Run the API

```r
library(plumber)
pr("plumber.R") %>%
  pr_run(port = 8000)
```

### Common Annotations

| Annotation | Description |
|------------|-------------|
| `@get /path` | GET endpoint |
| `@post /path` | POST endpoint |
| `@put /path` | PUT endpoint |
| `@delete /path` | DELETE endpoint |
| `@param name description` | Document parameter |
| `@serializer json` | JSON output |
| `@serializer png` | PNG image output |
| `@serializer csv` | CSV output |
| `@parser json` | Parse JSON input |
| `@filter name` | Define a filter |
| `@tag name` | OpenAPI tag |

### Dynamic Routes

```r
#* Get user by ID
#* @param id User ID
#* @get /users/<id>
function(id) {
  list(user_id = id)
}

#* Typed parameter
#* @get /items/<id:int>
function(id) {
  list(item_id = id)  # id is integer
}
```

### Serializers

```r
#* Return a plot
#* @serializer png
#* @get /plot
function() {
  plot(1:10)
}

#* Return CSV data
#* @serializer csv
#* @get /data
function() {
  mtcars
}

#* Return HTML
#* @serializer html
#* @get /page
function() {
  "<html><body><h1>Hello</h1></body></html>"
}
```

### Filters (Middleware)

```r
#* Log all requests
#* @filter logger
function(req) {
  cat(as.character(Sys.time()), "-",
      req$REQUEST_METHOD, req$PATH_INFO, "\n")
  forward()
}

#* Check authentication
#* @filter auth
function(req, res) {
  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401
    return(list(error = "Unauthorized"))
  }
  forward()
}
```

### Programmatic API Creation

```r
library(plumber)

pr() %>%
  pr_get("/hello", function() "Hello World") %>%
  pr_post("/echo", function(msg) msg) %>%
  pr_set_serializer(serializer_json()) %>%
  pr_run(port = 8000)
```

### Hooks

```r
pr("plumber.R") %>%
  pr_hook("preroute", function(req) {
    req$start_time <- Sys.time()
  }) %>%
  pr_hook("postroute", function(req, res) {
    elapsed <- Sys.time() - req$start_time
    message("Request took ", elapsed, " seconds")
  }) %>%
  pr_run()
```

### Error Handling

```r
pr("plumber.R") %>%
  pr_set_error(function(req, res, err) {
    res$status <- 500
    list(error = "Internal server error")
  }) %>%
  pr_run()
```

### File Upload

```r
#* Upload a file
#* @parser multi
#* @parser octet
#* @post /upload
function(req) {
  file_content <- req$body
  # Process file...
  list(success = TRUE)
}
```

### OpenAPI/Swagger

```r
pr("plumber.R") %>%
  pr_set_api_spec(function(spec) {
    spec$info$title <- "My API"
    spec$info$version <- "1.0.0"
    spec
  }) %>%
  pr_run()
```

## Key Functions

| Function | Description |
|----------|-------------|
| `plumb()` | Process a plumber API file |
| `pr()` | Create new Plumber router |
| `pr_run()` | Start the server |
| `pr_get/post/put/delete()` | Add endpoints |
| `pr_filter()` | Add filter |
| `pr_hook()` | Register hook |
| `pr_mount()` | Mount sub-router |
| `pr_static()` | Serve static files |
| `pr_set_serializer()` | Set default serializer |
| `forward()` | Continue to next handler |

## Reference Files

See `references/llms-txt.md` for complete API documentation including:
- All serializers and parsers
- Router methods and hooks
- R6 class constructors
- Cookie and session handling

## Hosting Options

- **Posit Connect**: Enterprise publishing platform
- **DigitalOcean**: Via `plumberDeploy` package
- **Docker**: Containerized deployment
- **PM2**: Process manager for Node.js (works with plumber)
