
# Load packages -----------------------------------------------------------

library(serial)
library(jsonlite)
library(tidyverse)
library(hms)
library(rtweet)
library(usethis)
library(ragg)
library(magick)
library(ggtext)
library(patchwork)

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

#prompt for room number
room <- readline(ui_line("Enter room number: "))

open(con)


# Start reading from sensor -----------------------------------------------

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


# Data wrangling ----------------------------------------------------------

#save "raw" data
write_csv(co2_df, paste0("data/", Sys.time(), "-", room,  "-data.csv"))

co2_df <-
  co2_df %>%
  mutate(date_time = lubridate::with_tz(date_time, tzone = "Canada/Eastern")) %>% 
  #remove abberantly low values
  filter(CO2 > 300) %>% 
  mutate(time = hms::as_hms(date_time),
         cat = case_when(
           CO2 <= 1000 ~ "1",
           CO2 > 1000 & CO2 <= 2000 ~ "2",
           CO2 > 2000 & CO2 <= 5000 ~ "3",
           CO2 > 5000 ~ "4"
         ))

# Summarize
summary <-
  co2_df %>%
  dplyr::summarize(co2_mean = round(mean(CO2)),
            co2_max = max(CO2),
            co2_min = min(CO2),
            co2_min_time = .$date_time[which.min(.$CO2)],
            co2_max_time = .$date_time[which.max(.$CO2)],
            start_time = min(date_time),
            end_time = max(date_time),
            durr = round(end_time - start_time)) %>% 
    mutate(
            cat = case_when(
              co2_mean <= 1000 ~ "1",
              co2_mean > 1000 & co2_mean <= 2000 ~ "2",
              co2_mean > 2000 & co2_mean <= 5000 ~ "3",
              co2_mean > 5000 ~ "4"
            ),
            emoji = case_when(
              co2_mean <= 1000 ~ "😀",
              co2_mean > 1000 & co2_mean <= 2000 ~ "🥱",
              co2_mean > 2000 & co2_mean <= 5000 ~ "😦",
              co2_mean > 5000 ~ "😵"
            )
  )


# Generate plot -----------------------------------------------------------
co2_colors = c(
  "1" = "#008037",
  "2" = "#FFBD59",
  "3" = "#FF914D",
  "4" = "#FF1616"
    )
bottom <-
  co2_df %>%
  ggplot(aes(x = time, y = CO2, color = cat, group = 1)) +
  geom_line(alpha = 0.6) +
  geom_point(size = 0.75) +
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
  theme(text = element_text(size = 12),
        axis.title.x = element_blank(),
        panel.grid = element_blank(),
        plot.margin = unit(c(5.5, 15, 5.5, 15), "points"))


label <- glue::glue("
                    <span style='font-size:35pt; color:{co2_colors[summary$cat]}'>{summary$co2_mean}</span>ppm <span style='font-size:35pt;'>{summary$emoji}</span>
                    <br>room: {room}     #esaCO2 
                    ")

top <- ggplot(summary) +
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

p <- top/bottom
p  
plot_file <- paste0("co2-", summary$end_time, ".png")
ggsave(
  plot_file,
  path = "img",
  plot = p,
  width = 1200,
  height = 675,
  units = "px"
)


# Construct the tweet -----------------------------------------------------
tweet <- glue::glue("Mean CO2 concentration in room {room} over the past {format(summary$durr)} is {summary$co2_mean}ppm (max = {summary$co2_max}ppm)\n#ESACO2")
alt <-
  glue::glue(
  "A line graph showing the CO2 concentration in ppm in room {room} between {format(summary$start_time, '%I:%M %p')} and {format(summary$end_time, '%I:%M %p')} roughly every 5 seconds.
  CO2 levels hit a minimum of {summary$co2_min} ppm at {format(summary$co2_min_time, '%I:%M %p')} and were at a maximum of {summary$co2_max}ppm at {format(summary$co2_max_time, '%I:%M %p')}."
)

#Preview tweet and prompt to send or not
magick::image_read(file.path("img", plot_file))
go <- ui_yeah(c("Ready to tweet?", ui_value(tweet)))

if(go){
  auth_as("co2-esa")
  
  post_tweet(
    status = tweet,
    media = file.path("img", plot_file),
    media_alt_text = alt
    )
  
}

