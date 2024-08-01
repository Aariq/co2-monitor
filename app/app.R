# Load libraries
library(shiny)
library(serial)
library(tidyverse)
library(lubridate)
library(patchwork)
library(ggtext)
library(shinyalert)
library(rtoot)

# Set up UI
ui <- fluidPage(
  plotOutput("co2"),
  textInput("room", "room number", value = "unknown"),
  actionButton("toot_btn", "Toot!", icon = icon("mastodon")),
  actionButton("reset_btn", "Reset", icon = icon("arrow-rotate-left"))
)

# Set up server
server <- function(input, output) {
  
  # Set up serial port reading --------------------------------------------------

  #figure out which port it's plugged into
  ports <- listPorts()
  co2_port <- ports[str_detect(ports, "^cu\\.usbmodem\\d+")]
  if(length(co2_port) == 0) {
    stop("Nothing is plugged in")
  }
  if(length(co2_port) > 1) {
    stop("More than one thing is plugged in")
  }

  con <- serialConnection(
    name = "co2",
    port = co2_port
  )

  open(con)

#TODO move to separate file & make function cat() current CO2 (for debug)
  # Function to get data ----------------------------------------------------

  get_data <- function(con, port) {
    stopifnot(isOpen(con) & port %in% suppressMessages(listPorts()))

    #try to read
    #Occasionally fails to parse when either there is no data in the buffer, or
    #there is more than one reading in the buffer.  We'll just throw those out
    #for simplicity I guess.
    co2_json <-
      try(read.serialConnection(con) %>%
            jsonlite::parse_json(), silent = TRUE)
    #if no data, return 0x0 tibble
    if(inherits(co2_json, "try-error")) {
      return(tibble::tibble())
    } else {
      co2_df <-
        as_tibble(co2_json) %>%
        mutate(date_time = Sys.time())
      cat(co2_df$CO2, "\n")
      return(co2_df)
    }
  }
  
  # initialise an empty dataframe as a reactiveValues object.
  # it is going to store all upcoming new data
  values <- reactiveValues(df = tibble::tibble())
  
  
  observeEvent(reactiveTimer(2000)(), {
    #triggers every 5 seconds
    values$df <- isolate({
      bind_rows(values$df, get_data(con, co2_port))
    })
  })

  output$co2 <- renderPlot({
    req(values$df$CO2)
    plot_co2(values$df, room = input$room)
  })
  
  #initialize empty toot
  toot <- reactiveValues(toot = character(), alt = character(), plot = character())
  
  #when toot button clicked
  observeEvent(input$toot_btn, {
    now <- Sys.time()
    
    #save raw data
    write_csv(values$df, paste0("../data/", now, "-", input$room,  "-data.csv"))
    
    #save plot
    p <- plot_co2(values$df, room = input$room)
    plot_file <- paste0("co2-", now, ".png")
    ggsave(
      filename = plot_file,
      path = "www/",
      plot = p,
      width = 1200,
      height = 675,
      units = "px"
    )
    
    #create toot text
    toot_list <- make_toot(values$df, room = input$room)
    
    #pop-up
    shinyalert(
      title = "Ready to toot?",
      text = glue::glue('{toot_list$toot}
                        <br>
                        <img src="{plot_file}" width = 400></img>'),
      html = TRUE,
      showCancelButton = TRUE,
      size = "m"
    )
   
    #update reactive toot object
    toot$toot <- toot_list$toot
    toot$alt <- toot_list$alt
    toot$plot <- plot_file
    
  })
  
  #when "ok" clicked in alert modal
  observeEvent(input$shinyalert, {
    if (isTRUE(input$shinyalert)) {
      post_toot(
        status = toot$toot,
        media = file.path("www", toot$plot),
        alt_text = toot$alt
      )
    }
  })
  
  #reset button
  observeEvent(input$reset_btn, {
    values$df <- tibble::tibble()
  })
}

# Run app
shinyApp(ui, server)
