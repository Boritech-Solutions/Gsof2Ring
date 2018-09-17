# GSOF2RING
A python module that uses PyEarthworm Library to inject RTX GSOF Messages into an Earthworm Ring

## Installation & Configuration

This module already assumes [Earthworm](http://earthwormcentral.org), [Anaconda Python](https://www.anaconda.com/download/#linux), and [PyEarthworm](https://github.com/Boritech-Solutions/GSOF2RING) are already installed and configured and with the same bit-size (32 or 64 bits). 

1. Download or clone the repository in an place accessible to executables for the user that runs earthworm.
2. In startstop_*.d add the command 'Gsof2Ring.sh' with the following parameters:
    1. -m: Module ID
    2. -r: Ring ID
    3. -p: Port of GPS Reciever
    4. -i: IP of GPS Reciever
    
The resulting commandline command should look like this:

    Gsof2Ring.sh -ring 1000 -m 8 -i 192.068.0.10 -p 28001

## Contact us

If you have any comment or question contact us at:

[Boritech Solutions](http://BoritechSolutions.com)

#### Acknowledgement:

The development and maintenance of Gsof2Ring is funded entirely by software and research contracts with Boritech Solutions.
