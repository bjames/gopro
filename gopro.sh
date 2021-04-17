trap cleanup TERM INT ERR
cleanup() {
    curl -s ${gopro_ip}"/gp/gpWebcam/STOP" >/dev/null 2>&1
    echo "sent STOP to GoPro"
    sudo modprobe -rf v4l2loopback
    echo "Removed video loopback device"
    pkill "ffmpeg -nostdin -threads 1 -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000'"
    echo "killed ffmpeg"
    exit
 }

if [[ $1 == '-h' ]];then
	# Display Help
	echo "Simple script to use a GoPro as a webcam"
	echo "Depends on v4l2loopback, ffmpeg and tcpdump"
	echo
	echo "Syntax: gopro.sh [-c[c]|p]"
	echo "options:"
	echo "p     Open a preview (uncropped in VLC)"
	echo "c     Crop the output to 720p"
	echo "cc    Crop the output to 480p"
	echo 
	echo "CTRL+C to quit"
	echo

    exit
fi

# create video loopback device
sudo modprobe v4l2loopback exclusive_caps=1 card_label='GoPro' video_nr=42
echo "created video loopback device /dev/video42"

# find the most recently attached cdc_ether
dev=$(dmesg | grep cdc_ether | grep -o enp[0-9a-z]* | tail -1)
echo "assuming $dev is our GoPro interface"

ip=$(ip -4 addr show dev ${dev} | grep -Po '(?<=inet )[\d.]+')
gopro_ip=$(echo ${ip} | awk -F"." '{print $1"."$2"."$3".51"}')
echo "using $gopro_ip as GoPro IP"

# send the start command
response=$(curl -s ${gopro_ip}"/gp/gpWebcam/START")
if [ $? -ne 0 ]; then
    echo "Error while starting the Webcam mode."
    cleanup
fi
echo "sent GoPro the START command"

# wait 5 seconds for the GoPro to start sending traffic
sleep 5

# use tcpdump to find the port the GoPro is sending from
goproport=$(sudo tcpdump -ni $dev -c 1 dst port 8554 2>/dev/null| grep -o '51.[0-9]*' | grep -o '.[0-9]*$' | cut -c2-)
echo "sending a packet to UDP $goproport so IPtables marks the traffic as established"
echo -n "gopro" | nc --send-only -u $gopro_ip $goproport -s $ip -p 8554 >/dev/null

echo "Starting stream CTRL + C to disable webcam"
if [[ $1 == '-cc' ]]; then
    echo "Stream will be cropped to 480p in the middle"
    ffmpeg -nostdin -threads 1 -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' -f:v mpegts -fflags nobuffer -vf 'format=yuv420p,crop=720:480' -f v4l2 /dev/video42 >/tmp/ffmpeggopro 2>&1 &
elif [[ $1 == '-c' ]]; then
    echo "Stream will be cropped to 720p in the middle"
    ffmpeg -nostdin -threads 1 -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' -f:v mpegts -fflags nobuffer -vf 'format=yuv420p,crop=1280:720' -f v4l2 /dev/video42 >/tmp/ffmpeggopro 2>&1 &
elif [[ $1 == '-p' ]]; then
    echo "Starting preview mode"
    vlc -vvv --network-caching=300 --sout-x264-preset=ultrafast --sout-x264-tune=zerolatency --sout-x264-vbv-bufsize 0 --sout-transcode-threads 4 --no-audio udp://@:8554 2>&1 &
else
    # no crop
    ffmpeg -nostdin -threads 1 -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' -f:v mpegts -fflags nobuffer -vf format=yuv420p -f v4l2 /dev/video42 >/tmp/ffmpeggopro 2>&1 &
fi

wait
