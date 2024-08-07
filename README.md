# co2-monitor

<!-- badges: start -->
<!-- badges: end -->

I'll be attending the 2024 US-RSE meeting and I'm concerned about ventilation and COVID-19 risk.  Rather than buying a CO2 sensor with a readout, I took some [advice on Twitter](https://twitter.com/MariannaFoos/status/1554492705492934660) and decided to [build my own](https://learn.adafruit.com/diy-trinkey-no-solder-air-quality-monitor). My plan is to share the data I collect on Mastodon.

This repository holds code to pull data from the Arduino trinkey kit and send a toot with `rtoot`.  When the Arduino trinkey is plugged into a USB port, running the code in `co2_monitor.R` will prompt the user for a room number and start collecting data.  When the trinkey is unplugged from the port, it will create a plot and some text and prompt the user if they'd like to post a toot with the plot and some info about the CO2 levels and the room number.

In `arduino/` there is the very slightly modified arduino code I'm using to send the data over serial (`co2_sender.ino`) as well as a forced re-calibration script I cobbled together **but did not test**.  Originally I thought the sensor needed re-calibration as it was reading ~500ppm outdoors, but then I just moved the sensor further away from my face and it reads ~420ppm.  So please use `forced_calibration.ino` at your own risk!

# References

Literature on CO2 as a proxy for COVID-19 risk:

- https://www.bmj.com/content/376/bmj.o736/rr-0
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8043197/
