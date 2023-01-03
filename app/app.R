# Load libraries
library(shiny)
library(serial)
library(tidyverse)
library(lubridate)
library(patchwork)
library(ggtext)

# Set up UI
ui <- fluidPage(
  plotOutput("co2")
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


  # Function to get data ----------------------------------------------------

  get_data <- function(con, port) {
    stopifnot(isOpen(con) & port %in% suppressMessages(listPorts()))

    #try to read
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

  #text output for now
  output$co2 <- renderPlot({
    co2_df <-
      values$df %>%
      mutate(date_time = lubridate::with_tz(date_time, tzone = "Canada/Eastern")) %>% 
      #remove abberantly low values
      filter(CO2 > 300) %>% 
      mutate(time = hms::as_hms(date_time),
             cat = case_when(
               CO2 <= 1000 ~ "1",
               CO2 > 1000 & CO2 <= 2000 ~ "2",
               CO2 > 2000 & CO2 <= 5000 ~ "3",
               CO2 > 5000 ~ "4"
             ), 
             emoji = case_when(
               CO2 <= 1000 ~ "😀",
               CO2 > 1000 & CO2 <= 2000 ~ "🥱",
               CO2 > 2000 & CO2 <= 5000 ~ "😦",
               CO2 > 5000 ~ "😵"
             ))
    
    
    # Generate plot -----------------------------------------------------------
    co2_colors = c(
      "1" = "#008037",
      "2" = "#FFBD59",
      "3" = "#FF914D",
      "4" = "#FF1616"
    )
    trace_plot <-
      co2_df %>%
      ggplot(aes(x = time, y = CO2, color = cat, group = 1)) +
      geom_line() +
      geom_point() +
      scale_x_time(
        labels = scales::label_time(format = "%I:%M %p"),
        breaks = scales::breaks_pretty(3)
      ) +
      scale_y_continuous(breaks = scales::breaks_pretty(4, min.n = 2)) +
      scale_color_manual(
        guide = "none",
        values = co2_colors
      ) +
      theme_bw() +
      labs(
        x = "Time",
        y = expression(CO[2]~(ppm))
      ) +
      theme(text = element_text(size = 18),
            axis.title.x = element_blank(),
            panel.grid = element_blank(),
            plot.margin = unit(c(5.5, 15, 5.5, 15), "points"))
    
    last_reading <- co2_df |> tail(1)
    label <- glue::glue("
                    <span style='font-size:35pt; color:{co2_colors[last_reading$cat]}'>{last_reading$CO2}</span>ppm <span style='font-size:35pt;'>{last_reading$emoji}</span>
                    ")
    
    top <- ggplot(last_reading) +
      geom_richtext(aes(
        x = 0,
        y = 0,
        label = label
      ),
      fill = NA,
      label.color = NA,
      size = 5) +
      scale_color_manual(
        guide = "none",
        values = co2_colors
      ) +
      theme_void()
    
    p <- top/trace_plot
    p
    
    
  })
}

# Run app
shinyApp(ui, server)
