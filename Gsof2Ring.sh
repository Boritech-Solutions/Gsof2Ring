#!/usr/bin/env python
from struct import unpack
import struct
import PyEW
import socket
import math
import argparse
import json
import http.client
import urllib
import sys
import numpy as np
from math import radians, sqrt, sin, cos
import configparser

# Mods by Alberto M. Lopez and Francisco Hernandez to deal with gps time to unix time
# taken from code time2time.py from https://raw.githubusercontent.com/igors/time2time/master/time2time.py
import optparse
import time
import datetime
from GSOF import Gsof

secsInWeek = 604800
secsInDay = 86400
UNIX2GPS         = 315964800  # seconds from UNIX to GPS epoch
#GPS_LEAP_SECONDS = 18         # leap seconds since GPS epoch (as of 4/18/2017)
# A note about the number above:  A constant offset between unix time and gps time exist=19, 
# but up to the date above there are 37 leap seconds, therefore, the difference is the number assigned above
# to the variable GPS_LEAP_SECONDS.
USE_UTC         = False

# Declare the station to be processed: PRSN - Puerto Rico Seismic Network and its ECEF XYZ position
#PRSN_X=2353900.1799
#PRSN_Y=-5584618.6433
#PRSN_Z=1981221.1234
#

def main():
    
    # Lets get the parameter file
    Config = configparser.ConfigParser()
    parser = argparse.ArgumentParser(description='This is a Trimble GSOF message parser')
    #parser.add_argument('-i', action="store", dest="IP",   default="localhost", type=str)
    #parser.add_argument('-p', action="store", dest="PORT", default=28001,          type=int)
    #parser.add_argument('-r', action="store", dest="RING", default=1000,           type=int)
    #parser.add_argument('-m', action="store", dest="MODID",default=8,              type=int)
    
    parser.add_argument('-f', action="store", dest="ConfFile",   default="gsof2ring.d", type=str)
    
    results = parser.parse_args()
    Config.read(results.ConfFile)
    
    # OPEN GSOF STREAM
    GPSRecv = Gsof()
    
    # Connect to GSOF
    GPSRecv.connect(Config.get('Station','IP'), int(Config.get('Station','PORT')))
    
    # Connect to EW
    Mod = PyEW.EWModule(int(Config.get('Earthworm','RING_ID')), int(Config.get('Earthworm','MOD_ID')), \
                        int(Config.get('Earthworm','INST_ID')), int(Config.get('Earthworm','HB')), False)
                        
    Station = Config.get('Station','NAME')
    Network = Config.get('Station','NETWORK')
    
    GPS_LEAP_SECONDS = int(Config.get('GPS','LEAP_SECONDS'))
    
    STAT_X = Config.get('GPS','X')
    STAT_Y = Config.get('GPS','Y')
    STAT_Z = Config.get('GPS','Z')
    
    # Remember dtype must be int32
    dt = np.dtype(np.int32)
    
    # Add output to Module as Output 0
    Mod.add_ring(int(Config.get('Earthworm','RING_ID')))
    
    connection_check = 0 
    
    while 1:
        
        ## Check if EW module is ok
        if Mod.mod_sta() is False:
            break
        
        # Try to read gsof stream
        try:
            GPSRecv.get_message_header()
            GPSRecv.get_records()
            
            # We got data
            connection_check = 0
            
            # PRINT GSOF STREAM; Open pos file
            #outfile = open ('positionlog_xyz', 'a')
            #print "X = %12.3f  Y = %12.3f  Z = %12.3f" % (GPSRecv.rec_dict['X_POS'], GPSRecv.rec_dict['Y_POS'], GPSRecv.rec_dict['Z_POS'])
            
            ## Format time
            gpsweek=(GPSRecv.rec_dict['GPS_WEEK'])
            tiempo=(GPSRecv.rec_dict['GPS_TIME'])/1000
            gpstime=gpsweek*secsInWeek + tiempo + GPS_LEAP_SECONDS
            unxtime=int(gpstime) + UNIX2GPS - GPS_LEAP_SECONDS
            fecha=(time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(unxtime)))
            #print "%i %i %i %i " % (gpsweek, tiempo, gpstime, unxtime)
            #print "%i LAT = %12.8f  LON = %12.8f  HT = %12.8f" % (unxtime, GPSRecv.rec_dict['LATITUDE'], GPSRecv.rec_dict['LONGITUDE'], GPSRecv.rec_dict['HEIGHT'])
            
            # Close pos file
            #outfile.write ( "%s %12.8f  %12.8f  %12.8f\n" % (fecha, GPSRecv.rec_dict['X_POS']-PRSN_X, GPSRecv.rec_dict['Y_POS']-PRSN_Y, GPSRecv.rec_dict['Z_POS']-PRSN_Z))
            #outfile.close()
            
            # Create EW Wave to send
            xdat = (GPSRecv.rec_dict['X_POS']-STAT_X)*1000
            X = {
              'station': Station,
              'network': Network,
              'channel': 'GPX',
              'location': '--',
              'nsamp': 1,
              'samprate': 1,
              'startt': unxtime,
              #'endt': unixtime+1,
              'datatype': 'i4',
              'data': np.array([xdat], dtype=dt)
            }
            
            ydat = (GPSRecv.rec_dict['Y_POS']-STAT_Y)*1000
            Y = {
              'station': Station,
              'network': Network,
              'channel': 'GPY',
              'location': '--',
              'nsamp': 1,
              'samprate': 1,
              'startt': unxtime,
              #'endt': unxtime + 1,
              'datatype': 'i4',
              'data': np.array([ydat], dtype=dt)
            }
            
            zdat = (GPSRecv.rec_dict['Z_POS']-STAT_Z)*1000
            Z = {
              'station': Station,
              'network': Network,
              'channel': 'GPZ',
              'location': '--',
              'nsamp': 1,
              'samprate': 1,
              'startt': unxtime,
              #'endt': unxtime + 1,
              'datatype': 'i4',
              'data': np.array([zdat], dtype=dt)
            }
            
            # Send to EW
            Mod.put_wave(0, X)
            Mod.put_wave(0, Y)
            Mod.put_wave(0, Z)
        
        # We are not getting good data
        except (struct.error, TypeError):
            if ( connection_check > 4 ) :
                print ("We have tried 5 times, shutting down so EW restarts me")
                Mod.goodbye()
            print("We cannot connect to the GPS, trying again in 1 minute.")
            time.sleep(60)
            connection_check = connection_check + 1
        
    
    print("gsof2ring has terminated")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        #outfile.close
        Mod.goodbye()
        print("\nSTATUS: Stopping, you hit ctl+C. ")
        #traceback.print_exc()
