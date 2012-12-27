from glue.client import Client, start_client

import urllib2, urllib
import json
import time
import MySQLdb


class ApeClient(Client):

    name = "Local MySQL"
    purpose = "reader"
    db = False

    def setup_data(self):
     try:
        self.db = MySQLdb.connect (host = "localhost",
                                   user = "root",
                                   passwd = "",
                                   db = "car") 
     except MySQLdb.error, e:
        print "Error %d: %s" % (e.args[0], e.args[1])
        time.sleep(5)
        self.setup_data()

    def query(self, values):
        if not self.db:
            self.setup_data()

        cursor = self.db.cursor()
        cursor.executemany("INSERT INTO `data_raw` (`dataset`, `timestamp`, `field`, `value`) VALUES (%s, %s, %s, %s)", values)
        #print "New rows: %d" % cursor.rowcount
        self.db.commit()
        cursor.close()
        #except MySQLdb, e:
        #    print "Error %d: %s" % (e.args[0], e.args[1])


    def read_data(self, message):

        values = []

        lines = message.split(")")
        for line in lines:

            dataset = line[ line.find('<') + 1 : line.find('>')]
            data = line.replace('<'+dataset+'>(', '').replace(')','').split(',')
            timestamp = False
            for d in data:
              if d != "":    
                field, value = d.split(":")
                if timestamp:
                    values.append( (dataset, timestamp, field, value) )
                else:
                    timestamp = value
         
        if len(values) > 0:
             self.query(values)

if __name__ == "__main__":
            start_client(client=ApeClient())
