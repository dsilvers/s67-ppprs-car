#!/usr/bin/python

from math import fabs
import sys
import tweepy

#finish_right = [43.09385, -89.35425]
#finish_left = [43.093883, -89.35435]

finish_right = [42.302383, -83.236383]
finish_left =  [42.302333, -83.236283]
finish_heading = 19

lat = 0
lon = 0
head = 0

lapnum = 0

# http://www.bryceboe.com/2006/10/23/line-segment-intersection-algorithm/

class Point:
    def __init__(self,x,y):
        self.x = x
        self.y = y

def ccw(A,B,C):
    return (C.y-A.y)*(B.x-A.x) > (B.y-A.y)*(C.x-A.x)

def intersect(A,B,C,D):
    return ccw(A,C,D) != ccw(B,C,D) and ccw(A,B,C) != ccw(A,B,D)

finish_right = Point(finish_right[0], finish_right[1])
finish_left = Point(finish_left[0], finish_left[1])
last = False
current = False

from glue.client import Client, start_client
class ApeClient(Client):

    name = "Local Ape"
    purpose = "reader"

    lap = 0
    last_lap_time = 0

    def tweet(self):

        CONSUMER_KEY = 'Ud3JmfKM8KIlTv5rmqYWw'
        CONSUMER_SECRET = 'sASEYyhLiNPsnEYxd7qHSZeeotgvu9ggUPwfJOkhx8'
        ACCESS_KEY = '113387825-wRpH3O3lk6coSY6NgjRkMyX1YxMmjEtGKES5EcDo'
        ACCESS_SECRET = 'iu1UUrKUfMDx9CmZ5wLm2VZAIX18yMfxDUtDrLuc0'

        if lap > 0:
            auth = tweepy.OAuthHandler(CONSUMER_KEY, CONSUMER_SECRET)
            auth.set_access_token(ACCESS_KEY, ACCESS_SECRET)
            api = tweepy.API(auth)

            time = ""
            if last_lap_time > 0:
                lap_time = int(round(time.time() - self.last_lap_time))
                if lap_time > 0:
                    minutes = int(lap_time / 60)
                    seconds = "%02d" % (int(laptime % 60)) 
                    time = " ("+str(minutes)+":"+str(seconds)+")"
            
            self.last_lap_time = time.time()

            # Sector67 Car: Lap 1 (1m54s) @PPPRS @makerfaire
            status = "Sector67 Car: Lap " + str(number) + time + " @PPPRS @makerfaire"

            self.log.info(status)
            #api.update_status(status)

    def read_data(self, message):

      global lapnum
      global lat
      global lon
      global head
      global last
      global finish_right
      global finish_left

      if message.find('<1SEC>') == 0:

        data = message.replace('<1SEC>', '').replace('(','').replace(')','')

        if data.find('<') == -1:

            try:
                data = data.split(",")
            except e:
                pass
            else:
                lat = 0
                lon = 0
                head = 0

                for d in data:
                    field, value = d.split(":")
                    if field == "lt":
                        lat = float(value)
                    elif field == "ln":
                        lon = float(value)
                    elif field == "h":
                        head = float(value)

                self.log.info("Location: " + str(lat) + ", " + str(lon) + " [" + str(head) + "]")

                if lat != 0 and lon != 0 and head != 0:
                    current = Point(lat, lon)
                    if last is not False and intersect(finish_right, finish_left, current, last):
                        # We've crossed the line!
                        self.log.info("Crossed the finish line...")
                        
                        # Check that we're heading in the correct direction
                        # create a Spread of +90/-90 degrees to check if we're headed the right way
                        adjusted_head = head - finish_heading

                        if adjusted_head >= 90 or adjusted_head <= -90:
                            # We're headed the wrong way!
                            self.log.info("Going the wrong way?")
                        else:
                            # Looks like we've actually completed a lap!
                            self.log.info("New Lap!")

                            lapnum = int(lapnum) + 1
    
                            file = open("lap.txt", "w")
                            file.write(str(lapnum))
                            file.close()

                            tweet(lapnum)
                        

                    #else:
                    # Still racin'...
                    last = current


if __name__ == "__main__":
    try:
        file = open("lap.txt", "r")
        lapnum = file.readline()
        file.close()
    except Exception:
        pass

    start_client(client=ApeClient())


