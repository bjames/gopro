trap cleanup TERM INT
cleanup() {
    curl -s ${mangled_ip}"/gp/gpWebcam/STOP"
    echo "sent STOP to GoPro"
    sudo modprobe -rf v4l2loopback
    echo "Removing video loopback device"
    exit
 }

# create video loopback device
sudo modprobe v4l2loopback exclusive_caps=1 card_label='GoproLinux' video_nr=42
echo "created video loopback device /dev/video42"

# find the most recently attached cdc_ether
dev=$(dmesg | grep cdc_ether | grep -o enp[0-9a-z]* | tail -1)
echo "assuming $dev is our GoPro interface"
ip=$(ip -4 addr show dev ${dev} | grep -Po '(?<=inet )[\d.]+')
mangled_ip=$(echo ${ip} | awk -F"." '{print $1"."$2"."$3".51"}')
echo "using $mangled_ip as GoPro IP"

# send the start command
response=$(curl -s ${mangled_ip}"/gp/gpWebcam/START")
if [ $? -ne 0 ]; then
    echo "Error while starting the Webcam mode."
    cleanup
fi 
echo "sent GoPro the START command"

echo "Starting stream CTRL + C to disable webcam"
ffmpeg -nostdin -threads 1 -i 'udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000' -f:v mpegts -fflags nobuffer -vf format=yuv420p -f v4l2 /dev/video42 >/dev/null 2>&1
