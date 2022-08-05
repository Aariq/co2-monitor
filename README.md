
# co2-monitor

<!-- badges: start -->
<!-- badges: end -->

I'll be attending the 2022 Ecological Society of America meeting and I'm concerned about ventilation and COVID-19 risk.  Rather than buying a CO2 sensor with a readout, I took some [advice on Twitter](https://twitter.com/MariannaFoos/status/1554492705492934660) and decided to [build my own](https://learn.adafruit.com/diy-trinkey-no-solder-air-quality-monitor). My plan is to share the data I collect using the Twitter hashtag [#ESACO2](https://twitter.com/hashtag/ESACO2), so follow (or mute) if you want to know about the ventilation situation.

This repository holds code to pull data from the Arduino trinkey kit and send a tweet with `rtweet`.  When the Arduino trinkey is plugged into a USB port, running the code in `co2_monitor.R` will prompt the user for a room number and start collecting data.  When the trinkey is unplugged from the port, it will create a plot and some text and prompt the user if they'd like to post a tweet with the plot and some info about the CO2 levels and the room number.


# References

Literature on CO2 as a proxy for COVID-19 risk:

- https://www.bmj.com/content/376/bmj.o736/rr-0
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8043197/
