#!/bin/bash

i=1
while [ $i -le $(($1)) ]; do
echo "Making additional Mopidy instance: $1"
echo "Executing Steps 1 & 2"
echo "
[core]
cache_dir = /var/cache/mopidy_$i
data_dir = /var/lib/mopidy_$i

[http]
port = 668$i

[audio]
output = audioresample ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! filesink location=/tmp/snapfifo_$i " > /etc/mopidy/mopidy_$i.conf

echo "Executing Step 5"
`sudo mkdir /var/cache/mopdiy_$i`
`sudo mkdir /var/lib/mopidy_$i`
`sudo chown mopidy:audio /var/cache/mopidy_$i /var/lib/mopidy_$i`

echo "Executing Step 6"
`sudo cp /usr/sbin/mopidyctl /usr/sbin/mopdiyctl_$i`
`sed -i "s/mopidy.conf\"$/mopidy.conf\:\/etc\/mopidy\/mopidy_1.conf\"/g" /usr/sbin/mopdiyctl_$i`

echo "Executing Step 7"
`sudo cp /lib/systemd/system/mopidy.service /lib/systemd/system/mopidy_$i.service`
`sed -i "s/mopidy.conf\"$/mopidy.conf\:\/etc\/mopidy\/mopidy_1.conf\"/g" /lib/systemd/system/mopidy_$i.service`
