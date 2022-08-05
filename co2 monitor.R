library(serial)
library(jsonlite)
library(tidyverse)
library(hms)

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

room <- readline("Enter room number: ")

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
        mutate(date_time = Sys.time())
    } else {
      co2_df <- 
        bind_rows(
          co2_df,
          as_tibble(co2_json) %>% 
            mutate(date_time = Sys.time())
      )
    }
  }
  #just for debugging:
  if (exists("co2_df")) {
    print(tail(co2_df))
  }
}

close(con)

#save example for plot development
# write_csv(co2_df, "example_data.csv")

co2_df <- 
  co2_df %>% 
  mutate(time = hms::as_hms(date_time))


#TODO: make a prettier plot, readable in a tweet
co2_df %>% 
  ggplot(aes(x = time, y = CO2, color = CO2)) +
  geom_line(alpha = 0.6) +
  geom_point() +
  scale_x_time(labels = scales::label_time(format = "%H:%M")) +
  #TODO actually want some kind of categorical color scale.  Need to find source for cutoffs
  scale_color_viridis_c(guide = "none") +
  theme_bw() +
  labs(
    x = "Time", #TODO include time zone
    y = expression(CO[2]~(ppm)),
    title = "#ESACO2",
    subtitle = glue::glue("room: {room}")
  ) +
  theme(text = element_text(size = 18))

#Construct the tweet:
summary <-
  co2_df %>% 
  summarize(co2_mean = round(mean(CO2)),
            co2_max = max(CO2),
            start_time = min(date_time),
            end_time = max(date_time),
            durr = round(end_time - start_time),
            #TODO: better cutoffs supported by actual data
            cat = case_when(
              co2_mean <= 1000 ~ "acceptable",
              co2_mean > 1000 & co2_mean <= 2000 ~ "worrying",
              co2_mean > 2000 ~ "'yikes!'"
            ))


glue::glue("CO2 is currently at {summary$cat} levels in room {room} (mean = {summary$co2_mean}ppm, max = {summary$co2_max}ppm over the past {summary$durr} minutes)\n#ESACO2")


#TODO: use rtweet to tweet it out
rm(co2_df)
