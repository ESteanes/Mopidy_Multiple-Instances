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

echo "Executing Step 4"
host=`sudo cat /etc/mopidy.conf | grep "^hostname" | sed "s/^[a-zA-Z =]*//g"`
echo "host = $host"
sudo sed -i "/^allowed_origins/ s/$/,$host:668$i/" /etc/mopidy.conf


echo "Executing Step 5"
sudo mkdir /var/cache/mopdiy_$i
sudo mkdir /var/lib/mopidy_$i
sudo chown mopidy:audio /var/cache/mopidy_$i /var/lib/mopidy_$i

echo "Executing Step 6"
sudo cp /usr/sbin/mopidyctl /usr/sbin/mopidyctl_$i
sed -i "s/mopidy.conf\"$/mopidy.conf\:\/etc\/mopidy\/mopidy_1.conf\"/g" /usr/sbin/mopdiyctl_$i

echo "Executing Step 7"
sudo cp /lib/systemd/system/mopidy.service /lib/systemd/system/mopidy_$i.service
sed -i "s/mopidy.conf$/mopidy.conf\:\/etc\/mopidy\/mopidy_1.conf\"/g" /lib/systemd/system/mopidy_$i.service

echo "Executing Step 8"
sudo sed -i "/\[stream\]/a pipe:\/\/\/tmp\/snapfifo_$i?name=Stream_$i" /etc/snapserver.conf

echo "Executing Step 9"
sudo "mopidy_$1" local scan

i=$(($i + 1))

done

sudo systemctl restart snapserver.service
sudo systemctl enable mopidy*.service
sudo systemctl start mopidy*.service 

echo "Done!"