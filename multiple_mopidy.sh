#!/bin/bash

if  test "$2" = "" 
then
    hostname="127.0.0.1"
else
    hostname="$2"
fi 

coreconfig="/etc/mopidy/mopidy.conf"
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
host=`sudo cat $coreconfig | grep "^hostname" | sed "s/^[a-zA-Z =]*//g"`
if test "$host" != ""
then
    hostname=$host
fi
echo "hostname = $hostname"

# latest mopidy.conf file doesn't have much content in it.
if grep -q "^allowed_origins" $coreconfig
then
    #need to check that we won't write a duplicate host name
    sudo sed -i "/^allowed_origins/ s/$/,$hostname:668$i/" $coreconfig
else
    echo "allowed_origins = $hostname:6680,$hostname:668$i" >> $coreconfig
fi

echo "Executing Step 5"
sudo mkdir -p /var/cache/mopidy_$i
sudo mkdir -p /var/lib/mopidy_$i
sudo chown mopidy:audio /var/cache/mopidy_$i /var/lib/mopidy_$i

echo "Executing Step 6"
sudo cp /usr/sbin/mopidyctl /usr/sbin/mopidyctl_$i
sed -i "s/mopidy.conf\"$/mopidy.conf\:\/etc\/mopidy\/mopidy_1.conf\"/g" /usr/sbin/mopidyctl_$i

echo "Executing Step 7"
sudo cp /lib/systemd/system/mopidy.service /lib/systemd/system/mopidy_$i.service
sed -i "s/mopidy.conf$/mopidy.conf\:\/etc\/mopidy\/mopidy_1.conf/g" /lib/systemd/system/mopidy_$i.service

echo "Executing Step 8"
#need to check we aren't duplicating stream entries
if test `sudo grep "pipe:\/\/\/tmp\/snapfifo_$i" /etc/snapserver.conf | wc -l` -eq 0
then
    sudo sed -i "/\[stream\]/a source = pipe:\/\/\/tmp\/snapfifo_$i?name=Stream_$i" /etc/snapserver.conf
fi

echo "Executing Step 9"
sudo "mopidy_$1" local scan

i=$(($i + 1))

done

sudo systemctl restart snapserver.service
sudo systemctl enable mopidy*.service
sudo systemctl start mopidy*.service 

echo "Done!"