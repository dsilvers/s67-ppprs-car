#!/usr/bin/python
from glue.client import Client

import asyncore
import logging
import serial
import time
import re
import os

class BasicModel():
    def __init__(self, name):
        self.name = name;
        self.value = None

class GPSModel():
    def __init__(self, name):
        self.name = name;
        self.value = None;
        if self.name == "lon":
            self.multiplier = -1    # Yeah, we're jerks and are just going to assume we're in North America.
        else:
            self.multiplier = 1

class AverageModel():

    def __init__(self, name):
    
        # Variable name of this data point
        self.name = name

        self.averages = { 1: None, 5: None, 15: None }
       
       
        # 1 second, 5 second and 15 second rolling average data
        # List will contain three items:
        #   Rolling average
        #   Number of data points in the 1 second rolling total
        #   Threshold for dragging on the trailing average
        self.data = { 1: [0, 0, 5], 
             5: [0, 0, 5],
             15:[0, 0, 15] }


    def add_data(self, dataset, value):
        if value == None:
            return

        self.data[dataset][0] += float(value)  
        self.data[dataset][1] += 1      # We've added a data point, count it!

    def generate_averages(self):
        one = self.calculate(1)

        # Add one second average to the five second value, and calulate that
        self.add_data(5, one)
        five = self.calculate(5)

        self.add_data(15, five)
        fifteen = self.calculate(15)
        
        try:
            self.averages = { 1: round(float(one), 2), 5: round(float(five), 2), 15: round(float(fifteen), 2) }
        except:
            self.averages = { 1: one,  5: five, 15: fifteen }
    
    def calculate(self, point):
        # No data! Return nothing.
        if self.data[point][1] == 0:
            return None

        # Calculate average
        average =  self.data[point][0] / self.data[point][1]
  
        points = self.data[point][2]
        # Tone down the count one if we've reached the max threshold we want to hang on to
        if(self.data[point][1] >= self.data[point][2]):
            points = points - 1

        self.data[point][0] = average * points
        self.data[point][1] = points

        return average


datasets = { "ax": BasicModel("ax"),
             "ay": BasicModel("ay"),
             "az": BasicModel("az"),
             "t1": BasicModel("t1"),
             "t2": BasicModel("t2"),
             "t3": BasicModel("t3"),
             "t4": BasicModel("t4"),
             "v": BasicModel("v"),
             "c": BasicModel("c"),
             "sp": BasicModel("sp"),
             "th": BasicModel("th"),
             "h": BasicModel("h"),
             "lt": GPSModel("lt"),
             "ln": GPSModel("ln")

}

    


class SerialPacketizer(Client):
    
    name = "Xbee"
    purpose = "writer"
    
    ports = [ "/dev/tty.usbserial-000013FD", "/dev/tty.usbserial-000014FA" ]
    speed = 9600
    max_read_chunk = 1024

    def setup_data(self):
        for port in self.ports:
            if os.path.exists(port):
                self.log.info("Using serial port: " + port)
                self.serial = serial.Serial(port, self.speed)
                return
            else:
                self.log.info("Skipping nonexistent port: " + port)
        self.log.info("Did not find a serial port that I can use. What's the deal?")
        quit()

    fragment = ""
    serial_data = ""
    packets = []
    def get_data(self):

        bytes = self.serial.inWaiting()
        if bytes > 0:
            self.serial_data = self.fragment + self.serial.read(bytes)
            self.fragment = ''
        else:
            return

        if self.serial_data != '':
            self.get_packets()
            if len(self.packets) > 0:
                for packet in self.packets:
                    self.say(packet)

        self.packets = []

    def clean_message(self, message):
        # Ever better, we'll match the packet format:
        # (variable:-34.54,variable:data,variable:34)
        # This is called below in get_packets()
        return re.match(r'^(,?[a-z0-9_]+:[A-Za-z0-9-.]+)+$', message)
    

    """
    # Attempt to recover a broken message
    
    So... I have no idea why this happens, but we seem to get a random dash of bad bits in the middle of a message.
    They always go in the patter of a ~ (tilde) followed by some null '\0' bits, a newline, more null bits, and ending with a digit.

    UPDATE: Ok, it looks like this may have been attributed to a loose connection in a the transmit pin going to the Xbee.

    (car)dan@dan-lappy ~/projects/car $ cat badness | hexdump 
    0000000 67 70 73 5f 74 69 6d 65 3a 30 36 30 30 31 38 2c
    0000010 67 70 73 5f 73 74 61 74 75 73 3a 56 2c 67 70 73
    0000020 5f 6c 61 74 3a 34 33 30 35 2e 36 34 39 34 2c 67
    0000030 70 73 5f 64 69 72 5f 6e 73 3a 4e 2c 67 70 73 5f
    0000040 6c 6f 6e 3a 30 38 39 32 31 2e 32 38 34 33 2c 67
    0000050 70 73 5f 64 69 72 5f 65 77 3a 57 2c 67 70 73 5f
    0000060 76 65 6c 7e 00 0a 00 00 3b 00 01 00 08 00 00 38   <---- This is the line with the badness!
    0000070 6f 63 69 74 79 3a 30 30 30 2e 30 2c 67 70 73 5f
    0000080 68 65 61 64 69 6e 67 3a 32 39 39 2e 37 2c 67 70
    0000090 73 5f 64 61 74 65 3a 30 37 30 37 31 31         
    000009d


    If a packet doesn't match the regular expression in clean_message(), we will attempt to chomp out the bad stuff.
    """
    def recover_message(self, message):
        new_message = ""

        # This is True if we find a tilde. It will be set back to False after we find the closing random 0-9 digit or forward slash.
        tilde = False

        # Loop through each character in the message
        for c in message:
            # Look for a digit
            if tilde:
                if re.match(r'\d|/', c):
                    tilde = False
            # Look for a tilde
            elif c == '~':
                tilde = True
            # Clean so far... add it to the recovered message.
            else:
                new_message += c
        # Return the recovered message
        return new_message


    
    def get_packets(self, last_position = 0):
        # If fragment is empty, we're looking for the beginning of a packet - that's a '('
        begin = self.serial_data.find('(', last_position)
        if begin > -1:
            # Attempt to find the other end of the packet
            end = self.serial_data.find(')', begin + 1)
            if end > -1:
                # Hey look, we found something. Let's save it and go up a level.
                packet = self.serial_data[begin + 1:end]

                clean = False
                if self.clean_message(packet):
                    clean = True
                else:
                    self.log.info("Broken packet, attempting repair")
                    new_packet = self.recover_message(packet)
                    if(self.clean_message(new_packet)):
                        self.log.info("Repair successful!")
                        packet = new_packet
                        clean = True
                    else:
                        self.log.info("Repair failed, here's the failed 'fixed' packet: *" + packet.decode('utf-8', 'ignore') + "*")

                if clean:
                    self.log.info(str(time.time()) + " Found good packet: " + packet)
                    
                    # Send the RAW packet on through
                    packet = "(timestamp:%s,%s)" % (int(time.time() * 1000), packet)
                    self.packets.append("<RAW>" + packet)

                    fresh_packet = []
                    
                    # Break apart packet and average the values
                    data = packet.replace('(','').replace(')','').split(',')

                    for d in data:
                        field, value = d.split(":")
                        try:
                            datasets[field].value = value
                        except KeyError:
                            if field != "timestamp":
                                fresh_packet.append([field, value ])

                        """
                        try:
                                # If the AverageModel class exists, use it
                                datasets[field]
                        except KeyError:
                                # Not an average model, just send it on through as an <ALL> packet so it reaches everywhere
                                if field != "timestamp":
                                    fresh_packet.append([field, value ])
                        else:
                                # It appears it's an average object. Let's add the data to it...
                                # The zero represents the 1-second average, the first and fastest set of data with unpredictable lengths
                                if datasets[field].__class__.__name__ == "BasicModel" or datasets[field].__class__.__name__ == "GPSModel":
                                    datasets[field].value = value
                                else:
                                    datasets[field].add_data(1, value)

                        """

                    # If there is data to send from non-averaged models, send them
                    send_packet("ALL", fresh_packet)
                
                else:
                    self.log.info("Found garbled packet, discarding it...")
                    self.log.info("The packet was: *" + packet.decode('utf-8', 'ignore') + "*")
                
                return False
            else:
            # Didn't find the end of the packet, so we'll just shove this chunk in the fragment
            # and deal with it next go-around.
                self.fragment = self.serial_data
                return False
        else:
            # Uh... nothing found. What the christ?
            return False


current_time = time.time()
# 1, 5, 15 second last check times
last_times = { 1: time.time(), 
               5: time.time(), 
               15: time.time() }

def convert_gps_to_degrees(val):
    try:
        if val[:1] == "0":
            val = val[1:]
        degrees = int(float(val) / 100)
        minutes = float(val) % 100
        return round( degrees + (minutes * 0.0166666667), 6)
    except Exception, e:
        return 0


def check_time_and_send(t):
    if current_time - t >= last_times[t]:
        # Time to send!
        
        packet = []
        for d in datasets:
            # If we're calculating the 1-second values, calculate all fifteen averages at once
            if t == 1:
                if datasets[d].__class__.__name__ == "AverageModel":
                    datasets[d].generate_averages()
                    packet.append( [datasets[d].name, datasets[d].averages[t] ] )
                elif datasets[d].__class__.__name__ == "GPSModel":
                    packet.append( [datasets[d].name, convert_gps_to_degrees(datasets[d].value)] * datasets[d].multiplier )
                else:
                    packet.append( [datasets[d].name, datasets[d].value ] )


        last_times[t] = time.time()
        logging.info("[" + str(t) + "SEC] Made packet")
        send_packet(str(t) + "SEC", packet)
    


# Build and send a packet
# Description is RAW, ALL, 1SEC, 5SEC or 15SEC
# Packet is a list of packets
#
# Packet will be formed as such:
#    <DESC>(timestamp:XXXXXX,field:value,....)
def send_packet(description, packet_data):
    
    if len(packet_data) == 0:
        return

    packet = "<%s>(timestamp:%s" % (description, (int(time.time() * 1000) ) )

    for d in packet_data:
        packet += ",%s:%s" % (d[0], d[1])

    packet += ")"

    client.say(packet)
    


if __name__ == "__main__":

    logging.basicConfig(level=logging.INFO)
    
    client = SerialPacketizer()
    client.setup_data()
    
    while 1:
        asyncore.poll(timeout=0.01)
        client.get_data()

        # Get and send averaged data if it's the correct time
        current_time = time.time()
        check_time_and_send(1);
        check_time_and_send(5);
        check_time_and_send(15);



