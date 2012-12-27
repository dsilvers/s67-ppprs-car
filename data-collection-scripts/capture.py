from glue.client import Client, start_client

import urllib2, urllib
import json
import time

class ApeClient(Client):

    name = "Local Ape"
    purpose = "reader"

    def read_data(self, message):

      if message.find('<1SEC>') == 0:

        raw_data = data
        data = message.replace('<1SEC>', '').replace('(','').replace(')','')

        if data.find('<') == -1:

            file = open("capture.txt", "a")
            file.write(raw_data)
            print "***" + raw_data

if __name__ == "__main__":
            start_client(client=ApeClient())
