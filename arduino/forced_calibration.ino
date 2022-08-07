/*
 * Copyright (c) 2020, Sensirion AG
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * * Neither the name of Sensirion AG nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <Adafruit_NeoPixel.h>
#include <Adafruit_BME280.h>
#include <SensirionI2CScd4x.h>
#include <Wire.h>

//--| User Config |-----------------------------------------------
#define DATA_FORMAT   0         // 0=CSV, 1=JSON
#define DATA_RATE     5000      // generate new number ever X ms
#define BEAT_COLOR    0x30D5C8  // neopixel heart beat color
#define BEAT_RATE     2000      // neopixel heart beat rate in ms, 0=none
#define CO2_REF       417       // reference CO2 in ppm for calibration
#define SAVE_EPROM    0         // should the recalibration be made permanent by saving to EPROM? 0=no, 1=yes
//----------------------------------------------------------------

Adafruit_BME280 bme;
SensirionI2CScd4x scd4x;
Adafruit_NeoPixel neopixel(1, PIN_NEOPIXEL, NEO_GRB + NEO_KHZ800);

uint16_t CO2, data_ready, correction;
float scd4x_temp, scd4x_humid;
float temperature, humidity, pressure;
int current_time, last_data, last_beat, starttime, endtime;

void setup() {
  Serial.begin(115200);

  // init status neopixel
  neopixel.begin();
  neopixel.fill(0);
  neopixel.show();

  // init BME280 first, this calls Wire.begin()
  if (!bme.begin()) {
    Serial.println("Failed to initialize BME280.");
    neoPanic();
  }

  // init SCD40
  scd4x.begin(Wire);
  scd4x.stopPeriodicMeasurement();
  if (scd4x.startPeriodicMeasurement()) {
    Serial.println("Failed to start SCD40.");
    neoPanic();
  }

  // init time tracking
  last_data = last_beat = millis(); 

  // wait until sensors are ready, > 1000 ms according to datasheet
  delay(1000);
  
  // start scd measurement in periodic mode, will update every 5 s
  scd4x.begin(Wire);
  scd4x.stopPeriodicMeasurement();
  if (scd4x.startPeriodicMeasurement()) {
    Serial.println("Failed to start SCD40.");
    neoPanic();
  }

  // wait for first measurement to be finished
  delay(4000);

  Serial.println("Equilibrating for 5 minutes");

  // measure continuously for 5 minutes
  starttime = millis();
  while ((millis() - starttime) <= (5*60*1000)) {
    current_time = millis();
      if (current_time - last_data > DATA_RATE) {
        temperature = bme.readTemperature();
        pressure = bme.readPressure() / 100;
        humidity = bme.readHumidity();
        scd4x.setAmbientPressure(uint16_t(pressure));
        scd4x.readMeasurement(CO2, scd4x_temp, scd4x_humid);
        switch (DATA_FORMAT) {
          case 0:
            sendCSV(); break;
          case 1:
            sendJSON(); break;
          default:
            Serial.print("Unknown data format: "); Serial.println(DATA_FORMAT);
          neoPanic();
        }
      last_data = current_time;
      }
    //------------
    // Heart Beat
    //------------
      if ((BEAT_RATE) && (current_time - last_beat > BEAT_RATE)) {
        if (neopixel.getPixelColor(0)) {
          neopixel.fill(0);
        } else {
          neopixel.fill(BEAT_COLOR);
        }
        neopixel.show();
        last_beat = current_time;
      }
  }
  Serial.println("Equilibration done!");
  
  // stop periodic measurement, wait 500 ms
  scd4x.stopPeriodicMeasurement();
  delay(500);

  // do the forced recalibration 
  Serial.println("Performing forced recalibration.");
  if (scd4x.performForcedRecalibration(CO2_REF, correction)) {
    Serial.println("Calibration failed.");
    neoPanic();
  }
  Serial.print("Correction factor: "); Serial.println(correction);
  scd4x.measureSingleShot();
  scd4x.readMeasurement(CO2, scd4x_temp, scd4x_humid);
  Serial.print("New CO2 measurement: "); Serial.println(CO2);
  
  // save the settings in EPROM
  if (SAVE_EPROM) {
    Serial.println("Saving calibration to EPROM");
    if (scd4x.persistSettings()) {
      Serial.println("Error in saving settings to EPROM");
      neoPanic();
    }
  }
 Serial.println("Calibration successful!");
}

void loop() {
   delay(8000);
}


// function definitions
void sendCSV() {
  Serial.print(CO2); Serial.print(", ");
  Serial.print(pressure); Serial.print(", ");
  Serial.print(temperature); Serial.print(", ");
  Serial.println(humidity);
}

void sendJSON() {
  Serial.print("{");
  Serial.print("\"CO2\" : "); Serial.print(CO2); Serial.print(", ");
  Serial.print("\"pressure\" : "); Serial.print(pressure); Serial.print(", ");
  Serial.print("\"temperature\" : "); Serial.print(temperature); Serial.print(", ");
  Serial.print("\"humidity\" : "); Serial.print(humidity);
  Serial.println("}");
}

void neoPanic() {
  while (1) {
    neopixel.fill(0xFF0000); neopixel.show(); delay(100);
    neopixel.fill(0x000000); neopixel.show(); delay(100);
  }
}
