# gopro
Simple script to use a GoPro as a webcam on Linux. Heavily inspired by https://github.com/jschmid1/gopro_as_webcam_on_linux, but I wanted to manually start and stop the camera as needed. 

## Usage
Simple script to use a GoPro as a webcam
Depends on v4l2loopback, ffmpeg and tcpdump
```
Syntax: gopro.sh [-c[c]|p]
options:
p     Open a preview (uncropped in VLC)
c     Crop the output to 720p
cc    Crop the output to 480p

CTRL+C to quit
```
