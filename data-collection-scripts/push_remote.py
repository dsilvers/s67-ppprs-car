from glue.client import Client, start_client

import urllib2, urllib
import json
import time

class ApeClient(Client):

    name = "Local Ape"
    purpose = "reader"

    def read_data(self, message):

      if message.find('<1SEC>') == 0:

        server = 'http://s67.org/publish/?id=car'
        #data = {'message':message

        data = message.replace('<1SEC>', '').replace('(','').replace(')','')

        if data.find('<') == -1:

            try:
                data = data.split(",")
            except e:
                pass
            else:
                message = {}

                # Timestmap should always be first
                for d in data:
                    field, value = d.split(":")
                    message[field] = value

                #data = urllib.urlencode(data)
                req = urllib2.Request(server, json.dumps(message))
                response = urllib2.urlopen(req)
                the_page = response.read()
                print the_page

if __name__ == "__main__":
            start_client(client=ApeClient())
