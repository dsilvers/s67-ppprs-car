#!/usr/bin/python

# http://www.bryceboe.com/2006/10/23/line-segment-intersection-algorithm/

class Point:
    def __init__(self,x,y):
        self.x = x
        self.y = y

def ccw(A,B,C):
    return (C.y-A.y)*(B.x-A.x) > (B.y-A.y)*(C.x-A.x)

def intersect(A,B,C,D):
    return ccw(A,C,D) != ccw(B,C,D) and ccw(A,B,C) != ccw(A,B,D)


a = Point(43.09385, -89.35425)
b = Point(43.093883, -89.35435)
c = Point(43.093766, -89.35439)
d = Point(43.09395, -89.35425)
e = Point(43.094016, -89.354216)

print intersect(a,b,c,d)
print intersect(a,b,d,e)
