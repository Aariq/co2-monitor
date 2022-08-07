library(serial)
library(jsonlite)
library(tidyverse)
library(hms)
library(rtweet)
library(usethis)
library(ragg)
library(magick)

#figure out which port it's plugged into
ports <- listPorts()
co2_port <- ports[str_detect(ports, "^cu\\.usbmodem\\d+")]
if(length(co2_port) == 0) {
  stop("Nothing is plugged in")
}
if(!length(co2_port) > 1) {
  stop("More than one thing is plugged in")
}

con <- serialConnection(
  name = "co2",
  port = co2_port
)

room <- readline(ui_line("Enter room number: "))

open(con)

#clear environment of previous results
rm(co2_df)

# This while() loop will continue until the sensor is unplugged.  Then the port
# it was plugged into will no longer be in `listPorts()` and the loop will
# break.  BIG caveat: this likely won't work if something *else* is plugged into
# a different USB port.

while(isOpen(con) & co2_port %in% suppressMessages(listPorts())) {
# Try reading from the USB every 5 sec (same as DATA_RATE defined in adafruit code)
  Sys.sleep(5)
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

#save "raw" data
write_csv(co2_df, paste0("data/", Sys.time(), "-rm", room,  "-data.csv"))

co2_df <-
  co2_df %>%
  #remove abberantly low values
  filter(CO2 > 300) %>% 
  mutate(time = hms::as_hms(date_time),
         cat = case_when(
           CO2 <= 1000 ~ "acceptable",
           CO2 > 1000 & CO2 <= 2000 ~ "moderate",
           CO2 > 2000 ~ "high"
         ))

# Summarize
summary <-
  co2_df %>%
  summarize(co2_mean = round(mean(CO2)),
            co2_max = max(CO2),
            co2_min = min(CO2),
            co2_min_time = .$date_time[which.min(.$CO2)],
            co2_max_time = .$date_time[which.max(.$CO2)],
            start_time = min(date_time),
            end_time = max(date_time),
            durr = round(end_time - start_time),
            #TODO: better cutoffs??
            cat = case_when(
              co2_mean <= 1000 ~ "acceptable",
              co2_mean > 1000 & co2_mean <= 2000 ~ "moderate",
              co2_mean > 2000 ~ "high"
            ))


# Make the plot
#TODO: make a prettier plot, readable in a tweet
#' - wider margin so numbers don't get cut off
#' - Big colored number somewhere
#' - emoji?
p <-
  co2_df %>%
  ggplot(aes(x = time, y = CO2, color = cat, group = 1)) +
  geom_line(alpha = 0.6) +
  geom_point() +
  scale_x_time(labels = scales::label_time(format = "%H:%M")) +
    scale_color_manual(
      guide = "none",
      values = c(acceptable = "green", moderate = "orange", high = "red")
    ) +
  theme_bw() +
  labs(
    x = "Time",
    y = expression(CO[2]~(ppm)),
    title = "#ESACO2",
    subtitle = glue::glue("room: {room}")
  ) +
  theme(text = element_text(size = 12))


plot_file <- paste0("co2-", summary$end_time, ".png")
ggsave(plot_file, path = "img", plot = p, width = 1200, height = 675, units = "px")

#Construct the tweet:
#TODO add emoji!
tweet <- glue::glue("CO2 is currently at {summary$cat} levels in room {room} (mean = {summary$co2_mean}ppm, max = {summary$co2_max}ppm over the past {summary$durr} minutes)\n#ESACO2")
alt <-
  glue::glue(
  "A line graph showing the CO2 concentration in ppm in room {room} between {format(summary$start_time, '%H:%M')} and {format(summary$end_time, '%H:%M')} roughly every 5 seconds.
  CO2 levels hit a minimum of {summary$co2_min} ppm at {format(summary$co2_min_time, '%H:%M')} and were at a maximum of {summary$co2_max}ppm at {format(summary$co2_max_time, '%H:%M')}."
)

#Preview tweet and prompt to send or not
magick::image_read(file.path("img", plot_file))
go <- ui_yeah(c("Ready to tweet?", ui_value(tweet)))

if(go){
  post_tweet(
    status = tweet,
    media = file.path("img", plot_file),
    media_alt_text = "testing testing"
  )
}

