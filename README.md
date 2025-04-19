# Shiny Authentication Example with Parquet

This is a simple Shiny application example that demonstrates user authentication using `shinyauthr` with `bslib` for the UI and Apache Arrow parquet files for user data storage.

Why I chose parquet?

I initally set this up to use a duckdb database but found it difficult to update the users table outside of the app while the app was running. I wanted this flexibility. This is because as of now duckdb doesn't support writing to the database from multiple processes see [here](https://duckdb.org/docs/stable/connect/concurrency.html).

## Features

- **User Authentication**: Secure login using the `shinyauthr` package with password hashing
- **Modern UI**: Sleek, responsive design with the `bslib` package
- **Efficient Data Storage**: User data stored in Apache Arrow parquet files
- **Admin Interface**: User management directly from within the app (admin users only)
- **On-Demand Data Refresh**: Refresh user data with a button click
- **Role-Based Access Control**: Different permissions for admin and standard users

## Setup Instructions

### Prerequisites

You need to have R installed along with the following packages:

```r
install.packages(c("shiny", "bslib", "shinyauthr", "arrow", "sodium", "dplyr", "reactable"))
```

### Steps to Run the Application

1. **Initialize the user data**:

   Run the `init_users.R` script to create the parquet file with sample users:

   ```r
   source("init_users.R")
   ```
2. **Run the Shiny app**:

   Run the Shiny application:

   ```r
   shiny::runApp()
   ```
3. **Login credentials**:

   Use one of the following credentials to log in:

   - Username: `admin`, Password: `admin123` (Admin privileges)
   - Username: `user1`, Password: `password1` (Standard privileges)
   - Username: `user2`, Password: `password2` (Standard privileges)

## User Management

### Adding Users Through the Admin Interface

When logged in as an admin user, you'll see a user management form at the bottom of the dashboard where you can:

1. Enter a new username (minimum 3 characters)
2. Set a password (minimum 6 characters)
3. Provide an email address
4. Assign permissions (admin or standard)
5. Click "Add User" to create the account

After adding a user, click the "Refresh User Table" button to see the updated user list.

### Resetting to Default Users

If you need to reset the user data back to the default users:

```r
Rscript init_users.R force
```

or from within R:

```r
source("init_users.R")
create_default_users(force = TRUE)
```

## Authentication Flow

1. Users enter their credentials on the login screen
2. Passwords are verified against sodium-hashed values in the parquet file
3. Upon successful authentication, users are granted access to the main dashboard
4. Admin users have additional privileges to view all users and add new accounts
5. The "Logout" button in the top-right corner ends the session

## Technical Details

### User Data Structure

The user data is stored in a parquet file with the following structure:

- `user`: Username (unique identifier)
- `password`: Sodium-hashed password
- `permissions`: User role ("admin" or "standard")
- `email`: User's email address

### Security Considerations

- Passwords are hashed using the `sodium` package
- The app uses reactive programming for efficient state management
- In a production environment, consider additional security measures:
  - HTTPS for data transmission
  - Rate limiting for login attempts
  - Regular backup of the parquet file
  - Secure file permissions for the parquet file
