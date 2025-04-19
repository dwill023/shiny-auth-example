library(arrow)
library(sodium)

# Constants
USERS_PARQUET_FILE <- "users.parquet"

# Create default users
create_default_users <- function(force = FALSE) {
  # Check if file already exists
  if (file.exists(USERS_PARQUET_FILE) && !force) {
    cat("Users parquet file already exists. Use force=TRUE to overwrite.\n")
    
    # Show existing users
    users <- arrow::read_parquet(USERS_PARQUET_FILE)
    cat("Current users in file:\n")
    print(users[, c("user", "permissions", "email")])
    
    return(FALSE)
  }
  
  # Create default users
  default_users <- data.frame(
    user = c("admin", "user1", "user2"),
    password = c(
      password_store("admin123"),
      password_store("password1"),
      password_store("password2")
    ),
    permissions = c("admin", "standard", "standard"),
    email = c("admin@example.com", "user1@example.com", "user2@example.com"),
    stringsAsFactors = FALSE
  )
  
  # Write to parquet file
  arrow::write_parquet(default_users, USERS_PARQUET_FILE)
  
  cat("Created users parquet file with default users.\n")
  return(TRUE)
}

# Check command line arguments
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  
  # Handle force parameter
  force <- FALSE
  if (length(args) > 0 && args[1] == "force") {
    force <- TRUE
  }
  
  create_default_users(force = force)
  
  cat("\nUsage:\n")
  cat("  Rscript init_users.R         # Initialize with default users (if file doesn't exist)\n")
  cat("  Rscript init_users.R force   # Reset to default users (overwrites existing file)\n")
} else {
  # Being sourced
  cat("Running init_users.R to create default users...\n")
  create_default_users()
} 
