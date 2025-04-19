library(shiny)
library(bslib)
library(shinyauthr)
library(sodium) # for password hashing
library(arrow) # for parquet files
library(dplyr)
library(reactable)

# Constants
USERS_PARQUET_FILE <- "users.parquet"

# Helper function to ensure users parquet file exists
ensure_users_file <- function() {
    if (!file.exists(USERS_PARQUET_FILE)) {
    message("Users parquet file not found. Please run init_users.R first.")
    
    # Return a minimal default admin user to ensure app can start
    return(data.frame(
        user = "admin",
        password = password_store("admin123"),
        permissions = "admin",
        email = "admin@example.com",
        stringsAsFactors = FALSE
    ))
    }

    # Read the parquet file
    tryCatch({
    users <- arrow::read_parquet(USERS_PARQUET_FILE)
    message("Successfully loaded ", nrow(users), " users from parquet file")
    return(users)
    }, error = function(e) {
    message("Error reading users parquet file: ", e$message)
    # Return a minimal default admin user on error
    return(data.frame(
        user = "admin",
        password = password_store("admin123"),
        permissions = "admin",
        email = "admin@example.com",
        stringsAsFactors = FALSE
    ))
    })
}

# UI
ui <- page_fillable(
    theme = bs_theme(version = 5, bootswatch = "flatly"),

    # Add authentication UI
    shinyauthr::loginUI("login"),

    # Main application UI that is only shown after authentication
    uiOutput("main_ui")
)

# Server
server <- function(input, output, session) {
    # Load users at startup (once)
    users_df <- ensure_users_file()

    # call the logout module with reactive trigger to hide/show
    logout_init <- shinyauthr::logoutServer(
    id = "logout",
    active = reactive(credentials()$user_auth)
    )

    # call login module supplying data frame, user and password cols
    credentials <- shinyauthr::loginServer(
    id = "login",
    data = users_df,
    user_col = user,
    pwd_col = password,
    sodium_hashed = TRUE,
    log_out = reactive(logout_init()),
    reload_on_logout = TRUE
    )

    # Authentication status output
    output$authentication_status <- reactive({
    credentials()$user_auth
    })
    outputOptions(output, "authentication_status", suspendWhenHidden = FALSE)

    # Function to add new user to parquet file
    add_user <- function(username, password, permissions, email) {
        tryCatch({
            # Get current users
            all_users <- arrow::read_parquet(USERS_PARQUET_FILE)
            
            # Create new user data
            new_user <- data.frame(
                user = username,
                password = password_store(password),
                permissions = permissions,
                email = email,
                stringsAsFactors = FALSE
            )
            
            # Add new user to existing users
            updated_users <- rbind(all_users, new_user)
            
            # Write updated users to parquet file
            arrow::write_parquet(updated_users, USERS_PARQUET_FILE)
            
            message("User added: ", username)
            return(TRUE)
        }, error = function(e) {
            message("Error adding user: ", e$message)
            return(FALSE)
        })
    }
    
    # Only show the main app UI if authenticated
    output$main_ui <- renderUI({
        req(credentials()$user_auth)
        
        fluidRow(
            column(
                width = 12,
                card(
                    card_header(
                        div(
                            class = "d-flex justify-content-between align-items-center",
                            h4("Welcome, ", strong(credentials()$info$user)),
                            shinyauthr::logoutUI("logout")
                        )
                    ),
                    card_body(
                        h2("Dashboard Content"),
                        p("This is a secure area of the application."),
                        p("You are logged in as: ", credentials()$info$user),
                        p("Your permission level is: ",
                        users_df$permissions[users_df$user == credentials()$info$user]),
                        hr(),
                        h3("User Management"),
                        p("The table below shows all users in the system."),
                        actionButton("refresh", "Refresh User Table", class = "btn-primary mb-3"),
                        reactableOutput("user_table"),
                        
                        # User management form (only for admin)
                        conditionalPanel(
                            condition = "output.is_admin = admin",
                            hr(),
                            h3("Add New User"),
                            div(
                                class = "row mb-3",
                                div(class = "col-md-6", textInput("new_username", "Username")),
                                div(class = "col-md-6", passwordInput("new_password", "Password"))
                            ),
                            div(
                                class = "row mb-3",
                                div(class = "col-md-6", textInput("new_email", "Email")),
                                div(class = "col-md-6", 
                                    selectInput("new_permissions", "Permissions", 
                                                choices = c("admin", "standard"),
                                                selected = "standard")
                                )
                            ),
                            actionButton("add_user_btn", "Add User", class = "btn-primary"),
                            textOutput("add_user_result")
                        )
                    )
                )
            )
        )
    })
    
    # Create is_admin output for conditionalPanel
    output$is_admin <- reactive({
        user_permissions <- users_df$permissions[users_df$user == credentials()$info$user]
        return(user_permissions == "admin")
    })
    outputOptions(output, "is_admin", suspendWhenHidden = FALSE)
    
    # Add user button handler
    observeEvent(input$add_user_btn, {
        
        # Basic validation
        if (nchar(input$new_username) < 3) {
            output$add_user_result <- renderText("Username must be at least 3 characters")
            return()
        }
        
        if (nchar(input$new_password) < 6) {
            output$add_user_result <- renderText("Password must be at least 6 characters")
            return()
        }
        
        # Add user
        result <- add_user(
            username = input$new_username,
            password = input$new_password,
            permissions = input$new_permissions,
            email = input$new_email
        )
        
        if (result) {
            # Clear inputs
            updateTextInput(session, "new_username", value = "")
            updateTextInput(session, "new_password", value = "")
            updateTextInput(session, "new_email", value = "")
            updateSelectInput(session, "new_permissions", selected = "standard")
            
            # Show success message
            output$add_user_result <- renderText("User added successfully!")
            
            # Refresh the user table
            updateActionButton(session, "refresh", label = "Refresh User Table")
        } else {
            output$add_user_result <- renderText("Failed to add user.")
        }
    })
    
    # Read users from parquet file, initially and on button press
    current_users <- eventReactive(
        list(input$refresh, 1), # Using 1 as an initial value to trigger on startup
        {
            tryCatch({
                message("Refreshing users table...")
                users <- arrow::read_parquet(USERS_PARQUET_FILE)
                return(users)
            }, error = function(e) {
                message("Error reading parquet file: ", e$message)
                return(data.frame(
                    user = character(),
                    permissions = character(),
                    email = character(),
                    stringsAsFactors = FALSE
                ))
            })
        },
        ignoreNULL = FALSE,
        ignoreInit = FALSE
    )
    
    # Render the user table (filtered for admin users)
    output$user_table <- renderReactable({
        req(credentials()$user_auth)
        
        users_data <- current_users()
        
        # Only show user data to admin users
        user_permissions <- users_df$permissions[users_df$user == credentials()$info$user]
        
        if (user_permissions == "admin") {
            users_to_display <- users_data %>%
                select(user, permissions, email) %>%
                arrange(user)
            
            reactable(
                users_to_display,
                striped = TRUE,
                highlight = TRUE,
                bordered = TRUE,
                filterable = TRUE,
                defaultPageSize = 10
            )
        } else {
            reactable(
                data.frame(message = "You do not have admin privileges to view user data."),
                columns = list(
                    message = colDef(name = "")
                )
            )
        }
    })
}

# Run the application
shinyApp(ui = ui, server = server) 