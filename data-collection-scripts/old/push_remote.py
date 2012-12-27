from glue.client import Client, start_client

import urllib2, urllib
import json
import time

class ApeClient(Client):

    name = "Local Ape"
    purpose = "reader"

    def read_data(self, message):

        server = 'http://dev.s67.org/publish/?id=car'
        #data = {'message':message

        #data = urllib.urlencode(data)
        req = urllib2.Request(server, message.replace(')(', ')\n(')) #json.dumps(message))
        response = urllib2.urlopen(req)
        the_page = response.read()

if __name__ == "__main__":
            start_client(client=ApeClient())
