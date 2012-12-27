///////////////////////////////////////////////////////////////////////
//
// PPPRS VEHICLE TELEMETRY
// Created for the Sector67 Detroit Maker Faire Power Racing Series entry
// July 2011
//
// ABOUT THE VEHICLE:
//      http://www.sector67.org/blog/2011/progress-on-the-power-wheels-project/
//      http://powerracingseries.org/blog/sector_67_the_mouse_that_roared/
//      http://www.sector67.org/blog/2011/sector67-sweeps-first-day-of-ppprs/
//  PHOTOS:
//      http://www.flickr.com/photos/dansilvers/sets/72157627130904010/
//
//
///////////////////////////////////////////////////////////////////////
// 
// SEE LICENSE FILE FOR LICENSE (BSD LICENSED)
//
// SOFTWARE CREDITS:
//
// Code written by Dan Silvers (dan@silvers.net) at Sector67 (http://www.sector67.org)
//
// Accelerometer code contributed by Chris "Ace" Meyer (waterppk@gmail.com) and Edwin Rogers (edwin.rodgers@gmail.com)
//
// Thermistor reading and temperature conversion code (specifically, the thermistor_read_pin() function) borrowed from:
//    Temperature Measurement with a Thermistor and an Arduino (Class Notes for EAS 199B, July 11, 2010)
//    Gerald Recktenwald (gerry@me.pdx.edu)
//    Mechanical and Materials Engineering Department, Portland State University, Portland, OR, 97201
//    Accessed July 2011
//    http://web.cecs.pdx.edu/~gerry/class/EAS199B/howto/thermistorArduino/thermistorArduino.pdf
//
///////////////////////////////////////////////////////////////////////
//
// HARDWARE AND OTHER CREDITS:
//
// Telemetry Hardware design:
//   Micah Erickson
//   Adam Godding 
//   Dan Silvers
//   Mark Ratzburg
//
// Vehicle Design and Engineering:
//   Micah Erickson
//   Alex McLees
//   Mark Ratzburg
//
// Data collection scripts, database and backend programming:
//   Dan Silvers
//
// Frontend Design:
//   Adam Godding
//
// Philosopher and Driver:
//   Tim Syth
//
// Hardware for Telemetry system was donated by:
//   Arduino Mega            Joe Kerman
//   Arduino Mega Shield     Chris "Ace" Meyer
//   Parallax GPS            Joe Kerman
//   LCD                     Chris "Ace" Meyer
//   Freescale Accelerometer Chris "Ace" Meyer
//   Zigbee Development Kit  Adam Godding
//
// Vehicle Sponsorship: (worth mentioning, even if unrelated to this telemetry system)
//   Isthmus Engineering        Scrap materials that were turned into motor/brake rotor/sprocket mounts
//   Renascence Manufacturing   Scrap aluminum square stock that was welded into a beautiful light weight frame
//   DreamBikes                 Pair of 130MM bicycle disc brakes to slow the machine down
//   Expedition Arts            Cash sponsorship from Expedition Arts to make the trip to KC and Detroit possible
//   5Nines                     Cash sponsorship from 5Nines internet hosting to make the trip to KC and Detroit possible
//   Technical Service          Loaned a 4QD controller and 2.5HP 36VDC electric motors
//   EV Powers                  Loaned us 14 Lithium Ion MottCell batteries
//   Flatt Cola                 Providing delicous cola
//  
//
// A total of $0 was spent assembling the data telemetry project. I'm not kidding. It was just 
// electronics parts we had laying around.
// 
// Thanks for Mark and Micah for putting up with my persistent EE questions. You
// gents have been troopers, I owe you both beer.
// 
// A huge thanks to everyone else who lent a hand.
//
///////////////////////////////////////////////////////////////////////

#include <Wire.h>            // Required for i2c to talk to accelerometer
#include <LiquidCrystal.h>   // LCD
#include "pitches.h"         // Startup "power on" tones

///////////////////////////////////////////////////////////////////////
// Zigbee module
// We are using a Xbee XB24 module. 
// 
// Chip Documentation: http://ftp1.digi.com/support/documentation/90000982_B.pdf
// Product Page:
// http://www.digi.com/products/wireless-wired-embedded-solutions/zigbee-rf-modules/point-multipoint-rfmodules/xbee-series1-module.jsp?tab=productdocs&pid=3257
//
// Wiring the Zigbee to the Arduino: 
// Pin #1 - VCC (3.3V) (top pin, left side)
// Pin #2 - DOUT
// Pin #3 - DIN
// Pin #10 - Ground (bottom pin, left side)
//
// Configuration details were partially taken from here:
// http://www.ladyada.net/make/xbee/arduino.html
//
// To program, it requires X-CTU, and that may or may not work only on WinXP.
// X-CTU: http://www.digi.com/support/kbase/kbaseresultdetl.jsp?kb=125
//
// I programmed them with the following method:
//
// RECEIVER (wired to the Arduino)
//     Connect with 9600 baud by default. We might change this later.
//     Modem configuration
//        Select "Show Defaults"
//        Change "ID - PAN ID" to 'F00D' . This is the 'network' that the zigbee will speak on.
//        Under I/O settings, "D3 - DIO3 Configuration" should be set to "3 - DI" (aka. Digital Input).
//        Also change "IC - DIO Change Detect" to "FF"
//     Click 'Write' to write the configuration.
//
// CONTROLLER (connected to laptop)
//     Connect with 9600 baud by default. We might change this later.
//     Modem configuration
//        Select "Show Defaults"
//        Change "ID - PAN ID" to 'F00D' . This is the 'network' that the zigbee will speak on.
//        Set "CE - Coordinator Enable" to 1.
//     Click 'Write' to write the configuration to the chip.
//     
// For the serial communication, some example code was taken from here, but rewritten a few times so it
// resembles the half step-brother, twice detached. It might still contain traces of non-original code.
// http://arduino.cc/forum/index.php?action=printpage;topic=51718.0
//
// We actually aren't going to use SoftwareSerial because we're using a Mega. We can use the speedy
// hardware serial instead, as documented on the Mega product page.
// If the ports change, we'll have to update the Serial3.whatever() lines.
//
// A bit more documentation about the Serial functions and class are here:
// http://arduino.cc/en/Serial/Begin
int zigbee_rx_pin = 14; // Connects to pin #3 on the Zigbee,
int zigbee_tx_pin = 15; // Connects to pin #2 on the Zigbee
int zigbee_baud_rate = 9600;


///////////////////////////////////////////////////////////////////////
// Thermistor pins
//
// (the wiring on our board has the pins for t3 and t4 swapped, which is why the analog inputs are out of order)
//
// Documentation for reading temperatures with thermistors and an Arduino:
// http://web.cecs.pdx.edu/~gerry/class/EAS199B/howto/thermistorArduino/thermistorArduino.pdf
//
//  t1 - Motor Controller
//  t2 - Left Motor
//  t3 - Right Motor
//  t4 - Ambient
//
int thermistor_num_pins = 4;
String thermistor_pin_names[4]         = {"t1", "t2", "t3", "t4"};   // These are used as variable names while returning data
int thermistor_pins[4]                 = {A2,   A3,   A5,   A4};    // Pin location of the thermistors
int thermistor_led_pins[4]             = {10,   11,   12,   0};      // LED pins - 0 means warning is disabled
int thermistor_warning_temperature[4]  = {45,   50,   50,   0};      // Threshold in degrees C - 0 means warning is disabled

float temperature_data[4]              = {0,    0,    0,    0};      // We'll cache the temperature data here
int thermistor_led_status[4]           = {0,    0,    0,    0};      // We save the status of the warning LEDs here - 1 is on, 0 is off


///////////////////////////////////////////////////////////////////////
// Status LEDs
//
// Yes, I screwed up wiring these. We're pushing 5V to them all the time. Therefore to turn them on, we set
// the LED pin to LOW instead of HIGH. Yeah, it sucks. But I'm not wiring the dash again.
//
int power_led_pin = 8;  // Power LED should be turned on at all times
int gps_led_pin = 9;    // On if we have a GPS signal, off otherwise

// Used for knight_rider() while cycling the LEDs
// We have a row of five LEDs that we use for() loops to cycle through and animate
int led_pin_start = 8;
int led_pin_end = 12;


///////////////////////////////////////////////////////////////////////
// Current Sensor
//
// An differential op-amp circuit and LEM HAL 100-S current sensor reads the amount of current
// going to the motors
//
//
// *****THIS MIGHT BE WRONG. it's probably the old version of the circuit.****
// Calibrations:
//   2.7V = 20A
//   2.46V = 12.5A
//   2.28V = 0A
//   2.1   = -12.5A
// Therefore, 69 amps per volt
int current_pin = A0;


///////////////////////////////////////////////////////////////////////
// Battery Voltage
//
// A voltage divider circuit is used to read the voltage of the batteries in the vehicle.
int voltage_pin = A1;
float voltage;            // Store the voltage here for safe-keeping, it will be displayed on the LCD.


///////////////////////////////////////////////////////////////////////
// Current
//
int current;


///////////////////////////////////////////////////////////////////////
// Throttle
//
int throttle_pin = A10;
int throttle;


///////////////////////////////////////////////////////////////////////
// GPS
//
// Parralx GPS uses a single RX pin for Serial2
// This should be connected to pin 17 on the ardino
//
// I used the example Arduino GPS code and it did not work. In fact, it was absolutely terrible.
// It ended up getting tossed out and I wrote my own.
int gps_baud_rate = 4800;    // The default baud rate of the parallax GPS is 4800.

float gps_lat, gps_lon;      // Stores the current GPS coordinates
float gps_speed;              // Container for GPS speed (velocity)
int gps_lock_status = 0;     // 1 = GPS has position data, 0 = lost in space. Used for LED control tracking.

// these two really aren't used anymore... but we'll keep it for good looks to keep attracting those beautiful women
int gps_num_variables = 10;  // The number of variables in the gps_variables array (below, you fool)
char* gps_variables[] = { "",             // 0 $GPR string, ignore it.
                          "",             // 1 Time in UTC (HhMmSs)
                          "gs",           // 2 Status - A = GPS locked on, V = no fix
                          "lt",           // 3 Latitude
                          "gps_ns",       // 4 Direction, North/South (N or S) [not sent over the zigbee, but we have to define something]
                          "ln",           // 5 Longitude
                          "gps_ew",       // 6 Direction, East/West (E or W) [not sent over the zigbee, but we have to define something]
                          "sp",           // 7 Velocity in knots, we convert to mph [sent as "sp" over the zigbee after conversion]
                          "h",            // 8 Heading, in degrees
                          ""              // 9 Date in UTC (DdMmAa)
                        };
                        

///////////////////////////////////////////////////////////////////////
// Accelerometer
//
// Huge, annoying note, accelerometer was mounted vertically, so X axis does not actually mean X in our case
//
// X = Z
// Y = Y
// Z = X
//
// We're using code that is borrowed from Chris' example
float accel_x, accel_y, accel_z;        // Accelerometer data

int accelerometer_address = 29;         // i2c address - 0x1D

// Calibrations required to make the reporting correct.
// x and y should be 0.0 at startup
// z should be -9.8 (that's gravity, folks)
int Offset10x = 120;
int Offset10y = -43;
int Offset10z = -36;


///////////////////////////////////////////////////////////////////////
// LCD Display
//
// We are using a yj-802A (HD44780 clone) display. It has 8 characters per row and 2 rows. It's quite tiny.
//
// We reference the LCD pins in our LCD object constructor
//   http://arduino.cc/en/Reference/LiquidCrystalConstructor
//   LiquidCrystal(rs, enable, d4, d5, d6, d7) 
LiquidCrystal lcd(2, 3, 5, 4, 7, 6);


///////////////////////////////////////////////////////////////////////
// Speaker
//
// Tone sounds for startup. See pitches.h for available tones.
int melody_pin = 13; // The pin our speaker/buzzer is connected to:
int melody_num_notes = 3; // The number of notes in the array below.
int melody[] = { NOTE_C4, NOTE_E4, NOTE_G4 }; // Notes in our song, from pitches.h
int noteDurations[] = { 10, 10, 10 }; // note durations: 4 = quarter note, 8 = eighth note, etc.:



///////////////////////////////////////////////////////////////////////
// SETUP FUNCTIONS
///////////////////////////////////////////////////////////////////////

void setup() 
{
  // A debugging pipe to our laptop for development
  Serial.begin(9600);
  
  // Enable LCD display
  // Write startup message
  lcd.begin(8,2);
  lcd.setCursor(0, 0);
  lcd.print("SECTOR67");
  lcd.setCursor(0, 1);
  lcd.print(" PPPRS");

  // Initialize the LED pins for output
  for(int i = led_pin_start; i <= led_pin_end; i++)
    pinMode(i, OUTPUT);
  
  // Colbert Head LED pins
  pinMode(26, OUTPUT);
  pinMode(27, OUTPUT);
  
  // Serial connection through the Zigbee
  Serial3.begin(zigbee_baud_rate);
  
  // Communicate with the GPS
  Serial1.begin(gps_baud_rate);
  
  // Initialize the Accelerometer
  accelerometer_setup();


  // Startup animation with LEDs and sound
  knight_sounds();
  knight_rider();
  knight_rider(); // Do this twice. Why? Because we're that awesome.

  
  // Turn on the power LED
  digitalWrite(power_led_pin, LOW);
  
}


// Plays a little tune during startup
void knight_sounds()
{
  // Taken from the arduino tones example
  
  // iterate over the notes of the melody:
  for (int thisNote = 0; thisNote < melody_num_notes; thisNote++) 
  {
    // to calculate the note duration, take one second 
    // divided by the note type.
    //e.g. quarter note = 1000 / 4, eighth note = 1000/8, etc.
    int noteDuration = 1000/noteDurations[thisNote];
    tone(melody_pin, melody[thisNote],noteDuration);

    // to distinguish the notes, set a minimum time between them.
    // the note's duration + 30% seems to work well:
    int pauseBetweenNotes = noteDuration * 1.30;
    delay(pauseBetweenNotes);
    // stop the tone playing:
    noTone(melody_pin);
  }
  
}


// Animate LEDs on dashboard during startup
void knight_rider()
{

  // Turn LEDs off:
  for(int i = led_pin_start; i <= led_pin_end; i++)
    digitalWrite(i, HIGH);
  
  // Animate LEDs forward
  for(int i = led_pin_start; i <= led_pin_end; i++) 
  {
    if(i != led_pin_start)
      digitalWrite(i - 1, HIGH);
    
    digitalWrite(i, LOW);
    delay(70);
  }
  
  // Animate LEDs backwards...
  for(int i = led_pin_end; i >= led_pin_start; i--)
  {
    if(i != led_pin_end)
      digitalWrite(i + 1, HIGH);
    
    digitalWrite(i, LOW);
    delay(70);
  }
  
}


///////////////////////////////////////////////////////////////////////
// Steven Colbert Light-Up Hood Ornament (R)
//
// Animate the LEDs in the Colbert head
//
// seq#, led1, led2
// 0   ON   OFF
// 1   ON   ON
// 2   OFF  ON
// 3   OFF  ON
// 4   ON   ON
// 5   ON   OFF
int colbert_sequence = 0;
int colbert_led1_pin = 26;
int colbert_led2_pin = 27;

void colbert_hood_ornament()
{
  switch (colbert_sequence) {
    
    case 0:
      digitalWrite(colbert_led1_pin, HIGH);
      break;
      
    case 1:
      digitalWrite(colbert_led2_pin, HIGH);
      break;
      
    case 2:
      digitalWrite(colbert_led1_pin, LOW);
      break;
      
    case 3:
      break;
      
    case 4:
      digitalWrite(colbert_led1_pin, HIGH);
      break;
      
    case 5:
      digitalWrite(colbert_led2_pin, LOW);
      colbert_sequence = -1;
      break;
  }
  
  colbert_sequence++;
}



///////////////////////////////////////////////////////////////////////
// MAIN LOOP
///////////////////////////////////////////////////////////////////////

void loop() 
{
  
  // Colbert Head Animation
  colbert_hood_ornament();
  //Serial.println("Colbert");
  
  // Get accelerometer data
  accelerometer_read();
  //Serial.println("Accelerometer");
  
  // Read temperatures
  //Serial.println("Start temps...");
  thermistors_read();
  //Serial.println("Temps done");
  
  // Read the voltage
  voltage_read();
  //Serial.println("Volts");
 
  // Send first batch of data
  send_data();
  //Serial.println("Data Sent #1!"); 
  
  // Read the current
  current_read();
  //Serial.println("Current");
  
  // Throttle
  throttle_read();
  //Serial.println("Throttle");
  
  // Read and parse GPS data  
  gps_read();
  //Serial.println("GPS done!");
  
  // Update the LCD screen
  lcd_update();
  //Serial.println("LCD");
  
  // Send the data to the serial port
  send_data();
  //Serial.println("Data sent! #2");
  
  // Scientifically set delay. OK, not really.
  // Timing this seems to be tricky. The GPS is set to spit out data every 100ms or so, so we catch the data every other cycle or so.
  // It takes some tweaking to find the correct value.
  //Serial.println("Sleeping...");
  delay(150);               
  //Serial.println("Waking...");
}




///////////////////////////////////////////////////////////////////////
// DATA HANDLING AND OUTPUT
///////////////////////////////////////////////////////////////////////

// Temporary string for add_data() to convert a float to a string
char temp[16];

// A buffer for the data that we'll be spitting back out over the
// Xbee connection.
String outbound_data;


// Add data to Zigbee output with an integer value
void add_data(String key, int value)
{
  add_data(key, String(value));   // Convert the value to a string, then add it.
}

// Add data with a float value
// This requires us to convert the float to a string using dtostrf()
void add_data(String key, float value)
{
  ftoa(temp, value, 2);  // Convert the float to a character string, then add it.
  add_data(key, temp);  
}

void add_data(String key, double value)
{
  ftoa(temp, value, 5);  // Convert the double to a character string, then add it.
  add_data(key, temp); 
}

// Add data with a string value to the outbound data
void add_data(String key, String value)
{
  if(outbound_data != "")
    outbound_data += ",";
  outbound_data += key + ":" + value;
}  



///////////////////////////////////////////////////////////////////////
// LCD OUTPUT
///////////////////////////////////////////////////////////////////////

void lcd_update()
{
  lcd.clear();
  
  // First line
  // VV.V  MPH
  lcd.setCursor(0, 0);
  lcd.print(voltage, 1);  // Round voltage to 1 decimal place. That's what the 1 in "lcd.print(voltage, 1)" is.
  if(voltage < 10)
    lcd.print(" ");
  lcd.print(" ");
  lcd.print(round(gps_speed));
  lcd.print(" ");
  lcd.print(" ");
  
  // Second line
  // Temperature data
  // XX XX XX
  lcd.setCursor(0, 1);
  lcd.print((int)temperature_data[0]);
  lcd.print(" ");
  lcd.print((int)temperature_data[1]);
  lcd.print(" ");
  lcd.print((int)temperature_data[2]);

}





///////////////////////////////////////////////////////////////////////
// ZIGBEE DATA HANDLING
///////////////////////////////////////////////////////////////////////
//
// Honestly, I got very angry with how the Serial() arduino class handles things. The buffer is small.
// It sucks. Anyway, excuse my rants in the comments.
//
int serial_buffer_size = 128; // Lame, lame, lame. Why do they make this so goddamn small?
int serial_buffer_counter = 0;
int serial_buffer_length = 0;

// Send data to the Xbee module
void send_data()
{
  if(outbound_data != "")
  {
    outbound_data = "(" + outbound_data + ")\n";
    // Ok, so the stupid arduino serial buffer is 128 bytes. Screw everything about this.
    // Anyway, let's attempt to deal with this.
    
    serial_buffer_length = outbound_data.length() / serial_buffer_size;
    if(outbound_data.length() % serial_buffer_size > 0)
      serial_buffer_length++;
    
    // Goddamit, we'll just buffer it ourselves  
    for(serial_buffer_counter = 0; serial_buffer_counter < serial_buffer_length; serial_buffer_counter++)
    {
      // Send 128 (or serial_buffer_size) bytes at a time
      Serial3.print( outbound_data.substring( serial_buffer_counter * serial_buffer_size, 
                                             (serial_buffer_counter + 1) * serial_buffer_size 
                                            ) 
                   );
    }
  }
  
  // Reset the outbound data cache
  outbound_data = "";
}





///////////////////////////////////////////////////////////////////////
// THERMISTORS
///////////////////////////////////////////////////////////////////////


// Read the thermistors
void thermistors_read()
{
  for(int i = 0; i < thermistor_num_pins; i++)
  {
     // Read the temperature
     temperature_data[i] = thermistor_read_pin(thermistor_pins[i]);
     
     // If the temperature is above the high threshold and the LED isn't turned on, turn it on
     if(temperature_data[i] >= thermistor_warning_temperature[i] && thermistor_led_status[i] == 0)
     {
       // Turn it on!
       digitalWrite(thermistor_led_pins[i], LOW); // Yes, this should be HIGH. But I wired it wrong.
       thermistor_led_status[i] = 1;
     }
     // If the temperature is below the high threshold and the LED is on, turn it off
     else if(temperature_data[i] < thermistor_warning_temperature[i] && thermistor_led_status[i] == 1)
     {
       // Turn it off.
       digitalWrite(thermistor_led_pins[i], HIGH); // Oh, it's you again. Yes, it's supposed to be LOW. But I wired it wrong.
       thermistor_led_status[i] = 0;
     }
     
     add_data(thermistor_pin_names[i], temperature_data[i]);
     
  }
  
}


// Read temperature from thermistor
//
// Returns a float in degrees celcius
//
// Used circuit documentation and code from:
//    Temperature Measurement with a Thermistor and an Arduino (Class Notes for EAS 199B, July 11, 2010)
//    Gerald Recktenwald (gerry@me.pdx.edu)
//    Mechanical and Materials Engineering Department, Portland State University, Portland, OR, 97201
//    Accessed July 2011
//    http://web.cecs.pdx.edu/~gerry/class/EAS199B/howto/thermistorArduino/thermistorArduino.pdf
//
float thermistor_read_pin(int Tpin) {

  int Vo;
  float logRt, Rt, T;
  float R = 9870;
    
  float c1 = 1.009249522e-03, c2 = 2.378405444e-04, c3 = 2.019202697e-07;
  
  //Serial.print("Reading Temp Pin");
  //Serial.println(Tpin);
    
  Vo = analogRead(Tpin);
  
  //Serial.print("Vo");
  //Serial.println(Vo);
  
  Rt = R*( 1024.0 / float(Vo) - 1.0 );
  logRt = log(Rt);
  
  //Serial.print("Maths: ");
  //Serial.println(1.0 / (c1 + c2*logRt + c3*logRt*logRt*logRt));
  
  T = ( 1.0 / (c1 + c2*logRt + c3*logRt*logRt*logRt ) ) - 273.15;
  
  if (T < 0)
    T = 0;
  
  if (T > 200)
    T = 200;
    
  //Serial.print("Final T ");
  //Serial.print(Tpin);
  //Serial.print(" ");
  //Serial.println(T);
    
  return T;
}





///////////////////////////////////////////////////////////////////////
// GPS
///////////////////////////////////////////////////////////////////////
// Read data from the Paralax GPS module
// Ideas borrowed from GPS tutorial, however this document sucks and the 
// example is actually entirely useless and can shove it where the light doesn't shine.
// http://www.arduino.cc/playground/Tutorials/GPS
// So, I guess I ended up mostly writing my own.

int gps_multiplier;          // Used while calculating GPS coordinates to convert N/S and E/W to a positive or negative longitude or latitude
int gps_last_comma = 0;      // Location of previously found comma. Used in gps_process_data()
int gps_next_comma = 0;      // Location of next comma. Used in gps_process_data()
char gps_read_char = 0;      // Placeholder for a read GPS byte in gps_read()
int gps_raw_pos = 0;         // Cursor position for our gps_raw character array.
int gps_bytes_available = 0; // Stores the available number of bytes in the Serial port in gps_read()
int gps_bytes_count = 0;     // Used as the loop counter in gps_read()
char gps_raw[300];           // Character buffer for gps_read(). Converted to a String object in gps_process_data(). Cleared out by gps_reset_raw()
String gps_raw_string;       // String object used in gps_process_data()
char gps_temp_array[16];     // Temporary character string for converting GPS coordinates from a float to a string object
String temp_string;          // A temporary value for the gps status


void gps_read()
{
  // Grab the number of bytes available from the GPS serial port
  gps_bytes_available = Serial1.available();
  
  //Serial.print("Bytes: ");
  Serial.println(gps_bytes_available);
  
  // Loop through and grab all the available bytes
  for(gps_bytes_count = 0; gps_bytes_count < gps_bytes_available; gps_bytes_count++)
  {
    // Read a byte
    gps_read_char = Serial1.read();
    
    // If we are past the first character and find a '$', it's time to process some data.
    if(gps_raw_pos > 0 && gps_read_char == 36)
    {
      gps_process_data();  
    }
    // If character is not a null character or CR, add it
    else if(gps_read_char != 0 && gps_read_char != 13)
    {
      gps_raw[gps_raw_pos] = gps_read_char;
      gps_raw_pos++;
    }
    
    // Time to stop if we've filled up the character array...
    // We'll just wipe it clean, because we never should have filled it up in the first place.
    if(gps_raw_pos == 300)
      gps_reset_raw();
  }
}


// Reset the character string that we are reading the GPS serial data into
// A slightly more efficient reset than the one below - only go up to the last position we wrote to.
void gps_reset_raw()
{ 
  gps_reset_raw_full(gps_raw_pos);
}


// Reset the ENTIRE character string that we are reading the GPS serial data into
void gps_reset_raw_full(int finish)
{
  //Serial.print("Resetting gps_raw.... ");
  //Serial.println(finish);
  
  for(int i = 0; i < finish && i < 300; i++)
    gps_raw[i] = 0;
  gps_raw_pos = 0;
  
  //Serial.println("Finshed a reset of gps_raw.");
}


// Process data read from the GPS
// 
// We look for the $GPRMC sentence that contains all the info we require for our telemetry data
//
// The parallax GPS outputs data in the NMEA format:
// http://aprs.gids.nl/nmea/
//
void gps_process_data()
{   
    // Our GPS data strings will begin with GPRMC
    // If we have a GPS location lock:
    //     <example?>
    // If we don't have a GPS lock:
    //     $GPRMC,020339,V,4305.6494,N,08921.2843,W,000.0,299.7,070711,,,N*76
    
    // Convert our quirky character array to a String object
    gps_raw_string = gps_raw;
    
    //Serial.println(gps_raw);
    //Serial.println("***");
    
    if(gps_raw_string.substring(0, 5) == "GPRMC")
    {
      
      for(int i = 0; i < gps_num_variables; ++i)
      {
          // Locate the next comma
          gps_next_comma = gps_raw_string.indexOf(',', gps_last_comma + 1);
          
          
          if(gps_next_comma == -1)
          {
            Serial.println("Bombing out, no next comma found...");
            break;
          }
          
          // If the variable name in the GPS variables names array is blank, skip it
          if (gps_variables[i] != "")
          {
            
            //Serial.print(i);
            //Serial.print(" ");
            //Serial.print(gps_variables[i]);
          //Serial.print(" ");
          //Serial.println(temp_string);
            
            // Strip the data string out of the GPS data using substring and the detected locations
            temp_string = gps_raw_string.substring(gps_last_comma + 1, gps_next_comma);
            
            // Check if we should change the GPS LED status
            // GPS status is the 3rd item in the list
            // "A" and "V" are the only valid data here
            if(i == 2 && (temp_string == "A" || temp_string == "V"))
            {
              
              if (temp_string == "A")
              {
                gps_led_control(1);
                add_data("gs", 1);
              }
              else
              {
                gps_led_control(0);
                add_data("gs", 0);
                break; // No GPS link, no data to report...
              }
            }              
            
            // Skip the gps_lat, gps_lon, gps_dir_ns and gps_dir_ew variables. We'll handle those as special cases.
            //else if(i >= 3 && i <= 6)
            //{
            //  temp_string.toCharArray(gps_temp_array, 16);
            
            // Save Latitude
            else if(i == 3)
                add_data("lt", temp_string);
                
            // Save Longitude
            else if(i == 5)
                add_data("ln", temp_string);
            
              /*
              // We're having all kinds of issues with the GPS thinking we're 40 miles north, so I assume there's something
              // terrible happening with calculating the positions
              //  
              // Process Latitude
              if(i == 4 || i == 6)
              {
                if(temp_string == "N" || temp_string == "E")
                  gps_multiplier = 1;
                // S or W
                else
                  gps_multiplier = -1;
                
                // Save latitude
                if(i == 4)
                {
                  add_data("lt", gps_lat * (float)gps_multiplier / 100.0);
                }
                // Save longitude
                else if(i == 6)
                {
                  add_data("ln", gps_lon * (float)gps_multiplier / 100.0);
                }
                
                
              }*/
              
            }
            
            // Velocity
            else if(i == 7)
            {
              // Convert velocity from knots to mph
              temp_string.toCharArray(gps_temp_array, 16);
              
              // Remove extraneous zeros from beginning of number, since atof() is dumb and gets confused.
              for(int j = 0; j < 16; j++)
              {
                if(gps_temp_array[i] == '0' && gps_temp_array[i + 1] == '0')
                {
                  // Shift the whole damn thing down
                  for(int k = 0; k < 15; k++)
                    gps_temp_array[k] = gps_temp_array[k + 1];
                  gps_temp_array[15] = 0;
                }
                else
                  // Oh hey, we're done.
                  break;
              }
              gps_speed = atof(gps_temp_array) * 0.87;
              add_data("sp", gps_speed);
            }
            
            // Heading
            else if(i == 8)
            {
              add_data("h", temp_string);
            }
          //}
          
          // Save the location of the comma for the next go-around
          gps_last_comma = gps_next_comma;
      }
      
    }
    
    // Reset our placeholder variables
    gps_last_comma = 0;
    gps_next_comma = 0;
    gps_reset_raw();
}


// Controls the LED for the GPS
// lock_status - A = GPS locked on, V = no fix
void gps_led_control(int new_lock_status)
{ 
  // If we have a lock and the LED is not turned on, light it up.
  if(new_lock_status == 1 && gps_lock_status == 0)
  {
    gps_lock_status = 1;
    digitalWrite(gps_led_pin, LOW);
  }
  // Lock lost, turn off the LED.
  else if(new_lock_status == 0 && gps_lock_status == 1)
  {
    gps_lock_status = 0;
    digitalWrite(gps_led_pin, HIGH);
  }
    
}





///////////////////////////////////////////////////////////////////////
// BATTERY VOLTAGE
///////////////////////////////////////////////////////////////////////

void voltage_read()
{
  // Adam's documentation says to multiply the readout by .00449 to get the
  // voltage.
  // At 8.67, the input is around 192
  // At 48V, the input should be 1022/1023-ish
  // Our spec says we should be able to read up to 48V
  
  voltage = analogRead(voltage_pin) * 0.048;
  //Serial.println("***");
  //Serial.println(analogRead(voltage_pin));
  add_data("v", voltage);
  
}


///////////////////////////////////////////////////////////////////////
// MOTOR CURRENT
///////////////////////////////////////////////////////////////////////
void current_read()
{
  current = analogRead(current_pin);
  add_data("c", current);
}


///////////////////////////////////////////////////////////////////////
// THROTTLE
//
// Full Open = 533
// Off = 161
//
// Yes, our throttle goes to 120%. It's a feature.
//
///////////////////////////////////////////////////////////////////////
void throttle_read()
{
   throttle = (analogRead(throttle_pin) - 171) * 0.32258;
   if(throttle < 3)
     throttle = 0;
   
   add_data("th", throttle); 
}


///////////////////////////////////////////////////////////////////////
// ACCELEROMETER
///////////////////////////////////////////////////////////////////////
// 
// All accelerometer code was contributed by:
//    Chris "Ace" Meyer (waterppk@gmail.com) and Edwin Rogers (edwin.rodgers@gmail.com)
//
// Code was slightly modified for our purposes.
//
// Our Accelerometer is on the i2c bus. We'll use the Wire library to speak to it.
//

byte code = 0x00;
int reading = 0;
int switchState = 0;

int xValue10 = 0;
int yValue10 = 0;
int zValue10 = 0;
int Offset10 = 0;
int OffsetMSB10 = 0;
int OffsetLSB10 = 0;

void accelerometer_setup()
{
  Wire.begin();
  Wire.beginTransmission(accelerometer_address);
  Wire.send(0x16);  //Configuration byte
  Wire.send(0x45);  //Write data
  //HEX data interpretation follows in binary:
  //Sets Data ready status not output 0
  //Sets SPI to 3 wire mode 1
  //Sets self test disabled 0
  //Sets measurement range to 2g 01
  //Sets measurement mode on 01
  Wire.endTransmission();
  
  Offset10x = -2*Offset10x;
  byte OffsetLSB10x = LSBFromInt(Offset10x);
  byte OffsetMSB10x = MSBFromInt(Offset10x);
  //Write the offset LSB
  setAccelMemory(0x10, OffsetLSB10x);
  setAccelMemory(0x11, OffsetMSB10x);
    
  Offset10y = -2*Offset10y;
  byte OffsetLSB10y = LSBFromInt(Offset10y);
  byte OffsetMSB10y = MSBFromInt(Offset10y);
  //Write the offset LSB
  setAccelMemory(0x12, OffsetLSB10y);
  setAccelMemory(0x13, OffsetMSB10y);
 
  Offset10z = -2*Offset10z;
  byte OffsetLSB10z = LSBFromInt(Offset10z);
  byte OffsetMSB10z = MSBFromInt(Offset10z);   
  //Write the offset LSB
  setAccelMemory(0x14, OffsetLSB10z);
  setAccelMemory(0x15, OffsetMSB10z);
}


void accelerometer_read()
{
  xValue10 = get10bitAccelData(1);
  yValue10 = get10bitAccelData(2);
  zValue10 = get10bitAccelData(3);
  
  accel_x = (xValue10 / 64.00) * 9.81;
  accel_y = (yValue10 / 64.00) * 9.81;
  accel_z = (zValue10 / 64.00) * 9.81;
  
  // !!!!!!!! Heads up!
  // Our X and Z axis are swapped!
  
  add_data("ax", accel_z);
  add_data("ay", accel_y);
  add_data("az", accel_x);
}


// Functions taken from the accelerometer sample code
int Signed10bit(byte msb, byte lsb) {
  word number = (int)(msb & B00000011) << 8 | lsb;
  
  if(msb & B00000010){
    //Negative Number
   return number - 0x400;
  } else {
    //Positive Number
    return number;
  }
}


byte LSBFromInt(int i) {  
  return (byte)(i & 0xFF); 
}


byte MSBFromInt(int i) {
  return (byte)((i>>8) & 0xFF);
}


// Pull 10 bit acceleration information
int get10bitAccelData(int axis){
  //Declare variables used in this scope
  word accel;
  byte data[2];
  byte LSB;
  byte MSB;
  
  Wire.beginTransmission(accelerometer_address); // open stream to write to max6965
  switch(axis) {
    case 1:
      code = 0x00; //Set register for X data
      break;
    case 2:
      code = 0x02;
      break;
    case 3:
      code = 0x04;
      break;
  }
  Wire.send(code);  //Request device i2c address
  Wire.endTransmission();  //Actually send queued data  
  Wire.requestFrom(accelerometer_address, 2);
  if(2 <= Wire.available()){    // if 2 bytes were received
    data[0] = Wire.receive();  // receive byte of acceleration data
    data[1] = Wire.receive();  // receive byte of acceleration data
    //Returns in the order in which they were requested
    LSB = data[0];    
    MSB = data[1];
    int value = Signed10bit(MSB,LSB);
    return value;
  }
}


void setAccelMemory(byte address, byte data){
  Wire.beginTransmission(accelerometer_address); // open stream to write to freescale accelerometer
  Wire.send(address);  //Mark memory destination
  Wire.send(data);  //Write memory
  Wire.endTransmission();
}


byte getAccelMemory(byte address){
  //Request Memory from Accelerometer
  Wire.beginTransmission(accelerometer_address); // Lets wake up the freescale accelerometer
  Wire.send(address);             // and ask it to transmit this memory address
  Wire.endTransmission();
  //now let's ask for the data
  Wire.requestFrom(accelerometer_address, 1);
  if(1 <= Wire.available())    // if 1 byte was received
  {
    reading = Wire.receive();  // receive high byte (overwrites previous reading)
    return reading;
  } else {
    reading = NULL;
    return reading;
  } 
}




///////////////////////////////////////////////////////////////////////////////
// MISC FUNCTIONS
///////////////////////////////////////////////////////////////////////////////


// Float/double to array
// Converts a floating point or double number to an array
//
// Borrowed from the arduino forums:
//   http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1164927646/6#6
char *ftoa(char *a, double f, int precision)
{
  long p[] = {0,10,100,1000,10000,100000,1000000,10000000,100000000};
  
  char *ret = a;
  long heiltal = (long)f;
  itoa(heiltal, a, 10);
  while (*a != '\0') a++;
  *a++ = '.';
  long desimal = abs((long)((f - heiltal) * p[precision]));
  itoa(desimal, a, 10);
  return ret;
}

