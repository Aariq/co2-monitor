library(serial)
library(jsonlite)
library(tidyverse)

#figure out which port it's plugged into
ports <- listPorts()
co2_port <- ports[str_detect(ports, "^cu\\.usbmodem\\d+")]
if(!length(co2_port)==1) {
  stop("more than one thing is plugged in")
}

con <- serialConnection(
  name = "co2",
  port = co2_port
)

#TODO: add a prompt for room number

open(con)

while(isOpen(con) & co2_port %in% suppressMessages(listPorts())) {
# Try reading from the USB every 0.2 sec
  Sys.sleep(0.2)
  co2_json <-
    try(read.serialConnection(con) %>% 
          jsonlite::parse_json(), silent = TRUE)
  
  if(!inherits(co2_json, "try-error")) {
    if(!exists("co2_df")) {
      
      co2_df <- 
        as_tibble(co2_json) %>% 
        mutate(time = Sys.time())
    } else {
      co2_df <- 
        bind_rows(
          co2_df,
          as_tibble(co2_json) %>% 
            mutate(time = Sys.time())
      )
    }
  }
  #just for debugging:
  if (exists("co2_df")) {
    print(co2_df)
  }
}

close(con)

#TODO: make a prettier plot, readable in a tweet
ggplot(co2_df, aes(x = time, y = CO2)) + geom_line()

#TODO: calc an average and a max CO2

#TODO: use rtweet to tweet it out
