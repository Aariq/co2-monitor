library(patchwork)

make_co2_plot <- function(df) {
  p <-
    co2_df %>%
    ggplot(aes(x = time, y = CO2, color = cat, group = 1)) +
    geom_line(alpha = 0.6) +
    geom_point(size = 0.75) +
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
    theme(text = element_text(size = 12),
          plot.margin = unit(c(5.5, 15, 5.5, 15), "points"))
  
  
  number <-
    ggplot(summary) +
    geom_text(aes(x = 0, y = 0, label = co2_mean, color = cat), size = 20) +
    scale_color_manual(
      guide = "none",
      values = c(acceptable = "green", moderate = "orange", high = "red")
    ) +
    theme_void()
  
  number/p
}