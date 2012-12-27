from glue.client import Client, start_client

import urllib2, urllib
import json
import sys

# Saves all messages to a logfile for replay later

class SaveClient(Client):

    name = "Archiver"
    purpose = "writer"

    def setup_data(self):
        self.logfile = open('data/' + sys.argv[1], 'w') 

    def read_data(self, message):

        self.logfile.write(message + "\n")

if __name__ == "__main__":
    start_client(client=SaveClient())
