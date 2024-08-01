read_trinkey <- function(con, port) {
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