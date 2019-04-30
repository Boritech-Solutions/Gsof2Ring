#!/usr/bin/env python

#    Gsof2Ring uses PyEarthWorm to interface the gsof messages from trimble to the EW Transport system.
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


import struct, PyEW, socket, math, argparse, json, http.client, urllib, sys
from logging.handlers import TimedRotatingFileHandler
from math import radians, sqrt, sin, cos
import configparser, logging, os
from struct import unpack
import numpy as np

# Mods by Alberto M. Lopez and Francisco Hernandez to deal with gps time to unix time
# taken from code time2time.py from https://raw.githubusercontent.com/igors/time2time/master/time2time.py
import optparse, time, datetime
from GSOF import Gsof

secsInWeek = 604800
secsInDay  = 86400
UNIX2GPS   = 315964800   # seconds from UNIX to GPS epoch
#GPS_LEAP_SECONDS = 18   # leap seconds since GPS epoch (as of 4/18/2017)
# A note about the number above:  A constant offset between unix time and gps time exist=19, 
# but up to the date above there are 37 leap seconds, therefore, the difference is the number assigned above
# to the variable GPS_LEAP_SECONDS.
USE_UTC         = False

# Declare the station to be processed: PRSN - Puerto Rico Seismic Network and its ECEF XYZ position
#PRSN_X=2353900.1799
#PRSN_Y=-5584618.6433
#PRSN_Z=1981221.1234

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
    
    # Setup the module logfile
    log_path = os.environ['EW_LOG']
    log_name = results.ConfFile.split(".")[0] + ".log"
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh = TimedRotatingFileHandler(filename=log_path + log_name, when='midnight', interval=1, backupCount=3)
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)
    logging.getLogger().addHandler(fh)
    logging.getLogger().setLevel(logging.DEBUG)
    logger=logging.getLogger('gsof2ew')
    
    # OPEN GSOF STREAM
    GPSRecv = Gsof()
    
    # Connect to GSOF
    GPSRecv.connect(Config.get('Station','IP'), int(Config.get('Station','PORT')))
    
    # Connect to EW
    Mod = PyEW.EWModule(int(Config.get('Earthworm','RING_ID')), int(Config.get('Earthworm','MOD_ID')), \
                        int(Config.get('Earthworm','INST_ID')), int(Config.get('Earthworm','HB')), False)
                        
    Station = Config.get('Station','NAME')
    Network = Config.get('Station','NETWORK')
    logger.info("Connecting to " + Station + " in " + Network + " at " + Config.get('Station','IP') + ":" + Config.get('Station','PORT'))
    
    GPS_LEAP_SECONDS = int(Config.get('GPS','LEAP_SECONDS'))
    
    STAT_X = float(Config.get('GPS','X'))
    STAT_Y = float(Config.get('GPS','Y'))
    STAT_Z = float(Config.get('GPS','Z'))
    
    NAME_X = str(Config.get('GPS','CHX'))
    NAME_Y = str(Config.get('GPS','CHY'))
    NAME_Z = str(Config.get('GPS','CHZ'))
    
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
            
        # We caught an RuntimeError Exception
        except RuntimeError:
            if ( connection_check > 4 ) :
                logger.error("We have tried 5 times, shutting down so EW restarts me")
                Mod.goodbye() # Shutsdown Module heartbeats stop EW restarts me
                break
            logger.warning("We cannot connect to the GPS, trying again in 10 sec...")
            time.sleep(10)
            connection_check = connection_check + 1
            continue
        except:
            logger.error("Fail: EW restarts me")
            Mod.goodbye()
            continue
        
        # PRINT GSOF STREAM; Open pos file
        #outfile = open ('positionlog_xyz', 'a')
        #print "X = %12.3f  Y = %12.3f  Z = %12.3f" % (GPSRecv.rec_dict['X_POS'], GPSRecv.rec_dict['Y_POS'], GPSRecv.rec_dict['Z_POS'])
        
        ## Format time
        gpsweek=(GPSRecv.rec_dict['GPS_WEEK'])
        tiempo=(GPSRecv.rec_dict['GPS_TIME'])/1000
#        gpstime=gpsweek*secsInWeek + tiempo + GPS_LEAP_SECONDS
        gpstime=gpsweek*secsInWeek + tiempo
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
          'channel': NAME_X,
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
          'channel': NAME_Y,
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
          'channel': NAME_Z,
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
    
    # Disconnect Gsof
    GPSRecv.disconnect()
    logger.info("gsof2ring has terminated")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        #outfile.close
        Mod.goodbye()
        print("\nSTATUS: Stopping, you hit ctl+C. ")
        #traceback.print_exc()
