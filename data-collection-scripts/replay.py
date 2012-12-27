#!/usr/bin/python
from glue.client import Client
import logging
import time
import asyncore

class SerialPacketizer(Client):
    name = "Replay"
    purpose = "writer"


if __name__ == "__main__":

    logging.basicConfig(level=logging.INFO)

    client = SerialPacketizer()

    while 1:
        asyncore.poll(timeout=0.01)

        file = open("capture.txt", "r")
            
        for line in file:
            logging.info(line)
            client.say(line)
            asyncore.poll(timeout=0.01)
            time.sleep(1)

        file.close()
