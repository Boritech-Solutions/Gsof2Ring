# GSOF2RING
A python module that uses PyEarthworm Library to inject RTX GSOF Messages into an Earthworm Ring

## Installation & Configuration

This module already assumes [Earthworm](http://earthwormcentral.org), [Anaconda Python](https://www.anaconda.com/download/#linux), and [PyEarthworm](https://github.com/Boritech-Solutions/GSOF2RING) are already installed and configured and with the same bit-size (32 or 64 bits). 

1. Download or clone the repository in an place accessible to executables for the user that runs earthworm.
2. Move the compiled PyEW shared library into the gsof2ring folder.
3. In startstop_*.d add the command 'Gsof2Ring.sh' with the following parameters:
    1. -p: Configuration file
    
The resulting commandline command should look like this:

    Gsof2Ring.sh -p <Path to config file>


### GSOF2RING.d configuration file

Unlike normal Earthworm modules, GSOF2Ring has a simpler type of configuration file. 
It has three major sections:
Earthworm: Contains EW Related INFO
RING_ID: The integer that has the Ring ID
MOD_ID: The integer that has the Module ID
INST_ID: The integer tha belongs to the Installation ID
Station
IP: The IP of the GSOF Station
PORT: The port of the GSOF protocol
NAME: The name of the GSOF station
NETWORK: The network of the station
GPS
X: The X reference coordinate
Y: The Y reference coordinate
Z: The Z reference coordinate
CHX: The channel name for the X position
CHY: The channel name for the Y position
CHZ: The channel name for the Z position
LEAP_SECONDS: The current number of GPS Leap Seconds

The following is an example of a configuration file (usually named gsof2ring.d): 

[Earthworm]
RING_ID: 1000
MOD_ID: 8
INST_ID: 141
HB: 30

[Station]
IP: 127.0.0.1
PORT: 10000
NAME: PRSN
NETWORK: PR

[GPS]
X: 2353900.1799
Y: -5584618.6433
Z: 1981221.1234
CHX: GPX
CHY: GPY
CHZ: GPZ
LEAP_SECONDS: 18

### GSOF2Ring.desc descriptor file
The descriptor files follows the normal Earthworm descriptor files structure and must include:

modName  gsof2ew
modId    MOD_GSOF2EW
instId  ${EW_INST_ID}

Where
modName: a unique name for this module (May include station name)
modId: a unique Module ID as stated in earthworm.d (must be the same in .d)
instId: usually left as  ${EW_INST_ID} (and must be the same one stated in .d)

## Contact us

If you have any comment or question contact us at:

[Boritech Solutions](http://BoritechSolutions.com)

#### Acknowledgement:

The development and maintenance of Gsof2Ring is funded entirely by software and research contracts with Boritech Solutions.
