def convert_gps_to_degrees(val):
    degrees = int(val / 100)
    minutes = val % 100
    return round( degrees + (minutes * 0.0166666667), 6)

print convert_gps_to_degrees(4305.6336)
print convert_gps_to_degrees(08921.2718) * -1
