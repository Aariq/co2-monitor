# Load libraries
library(shiny)
library(serial)
# initialize data frame
df <- tibble::tibble()
# Set up UI
ui <- fluidPage(
  titlePanel("Arduino Data Stream"),
  sidebarLayout(
    sidebarPanel(),
    mainPanel(
      p("hello"),
      textOutput("data"),
    )
  )
)

# Set up server
server <- function(input, output) {
  
  # Read data from Arduino
  readData <- function() {
    con <-
      serialConnection(name = "co2",
                       port = "cu.usbmodem14301",
                       newline = TRUE) 
    cat("opening connection")
    open(con)
    on.exit(close(con))
    Sys.sleep(5)
    cat("trying to read data")
    data <- read.serialConnection(con) |>
      jsonlite::parse_json(data) |> 
      tibble::as_tibble()
  }

  
  # Set up reactive timer
  timer <- reactiveTimer(5000) # Update every 5 seconds
  
  # Add data to data frame
  observe({
    timer() # Invalidate reactive timer to trigger update
    cat("timer went off")
    newData <- readData()
    df <- rbind(df, newData) # Add new data to data frame
  })
  
  # Display data
  output$data <- renderPrint({
    df
  })

}

# Run app
shinyApp(ui, server)
