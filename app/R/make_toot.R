make_toot <- function(data, room) {
  summary <-
    data %>%
    dplyr::summarize(co2_mean = round(mean(CO2)),
                     co2_max = max(CO2),
                     co2_min = min(CO2),
                     co2_min_time = .$date_time[which.min(.$CO2)],
                     co2_max_time = .$date_time[which.max(.$CO2)],
                     start_time = min(date_time),
                     end_time = max(date_time),
                     durr = round(end_time - start_time)) 
  
  toot <- glue::glue("Mean CO2 concentration in room {room} over the past {format(summary$durr)} is {summary$co2_mean}ppm (max = {summary$co2_max}ppm)\n#USRSE2024")
  alt <-
    glue::glue(
      "A line graph showing the CO2 concentration in ppm in room {room} between {format(summary$start_time, '%I:%M %p')} and {format(summary$end_time, '%I:%M %p')} roughly every 5 seconds.
  CO2 levels hit a minimum of {summary$co2_min} ppm at {format(summary$co2_min_time, '%I:%M %p')} and were at a maximum of {summary$co2_max}ppm at {format(summary$co2_max_time, '%I:%M %p')}."
    )
  
  list(toot = toot, alt = alt)
}
