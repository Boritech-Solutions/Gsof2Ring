#    Gsof2Ring is an example of how to use PyEW to interface the gsof messages from trimble to the EW Transport system.
#    Copyright (C) 2018  Francisco J Hernandez Ramirez
#    You may contact me at FJHernandez89@gmail.com, FHernandez@boritechsolutions.com
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>

import functools
import PyEW
import socket
import math
import argparse
import json
import http.client
import urllib
import sys
import numpy as np
from threading import Thread
from math import radians, sqrt, sin, cos

# Mods by Alberto M. Lopez and Francisco Hernandez to dealz with gps time to unix time
# taken from code time2time.py from https://raw.githubusercontent.com/igors/time2time/master/time2time.py
import optparse
import time
import datetime
from GSOF import Gsof

secsInWeek       = 604800
secsInDay        = 86400
UNIX2GPS         = 315964800  # seconds from UNIX to GPS epoch
GPS_LEAP_SECONDS = 18         # leap seconds since GPS epoch (as of 4/18/2017)
# A note about the number above:  A constant offset between unix time and gps time exist=19, 
# but up to the date above there are 37 leap seconds, therefore, the difference is the number assigned above
# to the variable GPS_LEAP_SECONDS.
USE_UTC         = False


# Declare the station to be processed: PRSN - Puerto Rico Seismic Network and its ECEF XYZ position
STA_X=2353900.1799
STA_Y=-5584618.6433
STA_Z=1981221.1234
#

class Gsof2Ring():

  def __init__(self, Station = 'PRSN', Network = 'PR', IP = "localhost", PORT = 10000):
    # Create a thread for the Module
    self.myThread = Thread(target=self.run)

    # Start an EW Module with parent ring 1000, mod_id 8, inst_id 141, heartbeat 30s, debug = False (MODIFY THIS!)
    self.gsof2ring = PyEW.EWModule(1000, 8, 141, 30.0, False) 

    # Add our Input ring as Ring 0
    self.gsof2ring.add_ring(1000)

    # Allow it to start
    self.runs = True
    
    # OPEN GSOF STREAM
    self.GPSRecv = Gsof()
    
    # Init Variable
    self.Station = Station
    self.Network = Network
    
    # Connect to GSOF
    self.GPSRecv.connect(IP, PORT)
    
    # Remember dtype must be int32
    self.dt = np.dtype(np.int32)
    
  def getGps(self):  
    # READ GSOF STREAM
    self.GPSRecv.get_message_header()
    self.GPSRecv.get_records()

    # PRINT GSOF STREAM; Open pos file
    #outfile = open ('positionlog_xyz', 'a')
    #print "X = %12.3f  Y = %12.3f  Z = %12.3f" % (GPSRecv.rec_dict['X_POS'], GPSRecv.rec_dict['Y_POS'], GPSRecv.rec_dict['Z_POS'])
    
    ## Format time
    gpsweek=(self.GPSRecv.rec_dict['GPS_WEEK'])
    tiempo=(self.GPSRecv.rec_dict['GPS_TIME'])/1000
    gpstime=gpsweek*secsInWeek + tiempo + GPS_LEAP_SECONDS
    unxtime=int(gpstime) + UNIX2GPS - GPS_LEAP_SECONDS
    fecha=(time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(unxtime)))
    #print "%i %i %i %i " % (gpsweek, tiempo, gpstime, unxtime)
    #print "%i LAT = %12.8f  LON = %12.8f  HT = %12.8f" % (unxtime, GPSRecv.rec_dict['LATITUDE'], GPSRecv.rec_dict['LONGITUDE'], GPSRecv.rec_dict['HEIGHT'])
    
    # Close pos file
    #outfile.write ( "%s %12.8f  %12.8f  %12.8f\n" % (fecha, GPSRecv.rec_dict['X_POS']-STA_X, GPSRecv.rec_dict['Y_POS']-STA_Y, GPSRecv.rec_dict['Z_POS']-STA_Z))
    #outfile.close()
    
    # Create EW Wave to send
    xdat = (self.GPSRecv.rec_dict['X_POS']-STA_X)*1000
    X = {
      'station': self.Station,
      'network': self.Network,
      'channel': 'GPX',
      'location': '--',
      'nsamp': 1,
      'samprate': 1,
      'startt': unxtime,
      #'endt': unixtime+1,
      'datatype': 'i4',
      'data': np.array([xdat], dtype=self.dt)
    }
    
    ydat = (self.GPSRecv.rec_dict['Y_POS']-STA_Y)*1000
    Y = {
      'station': self.Station,
      'network': self.Network,
      'channel': 'GPY',
      'location': '--',
      'nsamp': 1,
      'samprate': 1,
      'startt': unxtime,
      #'endt': unxtime + 1,
      'datatype': 'i4',
      'data': np.array([ydat], dtype=self.dt)
    }
    
    zdat = (self.GPSRecv.rec_dict['Z_POS']-STA_Z)*1000
    Z = {
      'station': self.Station,
      'network': self.Network,
      'channel': 'GPZ',
      'location': '--',
      'nsamp': 1,
      'samprate': 1,
      'startt': unxtime,
      #'endt': unxtime + 1,
      'datatype': 'i4',
      'data': np.array([zdat], dtype=self.dt)
    }
    
    # Send to EW
    self.gsof2ring.put_wave(0, X)
    self.gsof2ring.put_wave(0, Y)
    self.gsof2ring.put_wave(0, Z)
  
  def run(self):
  
    # The main loop
    while self.runs:
      if self.gsof2ring.mod_sta() is False:
        break
      time.sleep(0.001)
      self.getGps()
    self.gsof2ring.goodbye()
    quit()
    print ("Exiting")
      
  def start(self):
    self.myThread.start()
    
  def stop(self):
    self.runs = False
