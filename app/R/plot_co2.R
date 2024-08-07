plot_co2 <- function(data, room) {
  co2_df <-
    data |> 
    mutate(date_time = lubridate::with_tz(date_time, tzone = "US/Mountain")) |> 
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
  
  co2_colors <- c(
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
    theme_bw() 
  
  last_reading <- co2_df |> tail(1)

  title_style <- 
    classic_style() |> 
    modify_style(
      "big",
      size = em(2.2) #2.2x as big
    )
  
  title_md <-
    glue::glue(
      "{.big {<<co2_colors[last_reading$cat]>> <<last_reading$CO2>>}}ppm {.big <<last_reading$emoji>>}",
      .open = "<<", .close = ">>"
    )
  subtitle_md <- 
    glue::glue("Room <<room>> {.grey |} {.blue #USRSE2024}", .open = "<<", .close = ">>")
  
  trace_plot +
    labs(
      title = title_md,
      subtitle = subtitle_md,
      x = "Time",
      y = expression(CO[2]~(ppm))
    ) +
    theme(text = element_text(size = 12),
          axis.title.x = element_blank(),
          panel.grid = element_blank(),
          plot.title = element_marquee(style = title_style, hjust = 0.5, margin = margin(b=-10)),
          plot.subtitle = element_marquee(hjust = 0.5, margin = margin(t=-10, b = -5)))
}
