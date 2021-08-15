#!/usr/bin/bash
Help(){
   # Display Help
   echo "Syntax: multiple_mopidy.sh [-H|n|o|r|h|v|V]"
   echo "options:"
   echo "Capital options are required, lower case are not required."
   echo "H     Hostname you want to define"
   echo "N     Number of mopidy instances you want"
   echo "O     Output you want mopidy to go to ([snapcast]/more to be added)"
   echo "r     Removes all additional instances and clears up /etc/mopdiy/mopidy.conf. Will only clear up files made with the naming scheme found in this script"
   echo "h     Print this Help."
   echo "v     Verbose mode."
   echo "i     Print software version and exit."
   echo "Only the last of multiple commands will be taken."
   exit 0
}
VerboseEcho(){
    if test "$verbose" = true ;then
            echo "$1"
    fi
}
CreateInstance(){
    i=1
    while [ $i -le $(($numInstance)) ]; do
        echo "Making additional Mopidy instance: $i"
        VerboseEcho "Executing Steps 1 & 2"   
        echo "[core]
cache_dir = /var/cache/mopidy_$i
data_dir = /var/lib/mopidy_$i

[http]
port = 668$i

[audio]
${audioOut}_${i} " > /etc/mopidy/mopidy_$i.conf
        VerboseEcho "Executing Step 4"
        # latest mopidy.conf file doesn't have much content in it.
        if grep -q "^allowed_origins" $coreconfig
        then
            #need to check that we won't write a duplicate host name
            if grep -q "$hostname:668$i" $coreconfig
            then
                VerboseEcho "allowed origins at $hostname:668$i already exists"
            else 
                sudo sed -i "/^allowed_origins/ s/$/,$hostname:668$i/" $coreconfig
            fi
        else
            
            echo "allowed_origins = $hostname:6680,$hostname:668$i" >> $coreconfig
        fi
        
        VerboseEcho "Executing Step 5"
        sudo mkdir -p /var/cache/mopidy_$i
        sudo mkdir -p /var/lib/mopidy_$i
        sudo chown mopidy:audio /var/cache/mopidy_$i /var/lib/mopidy_$i
        
        VerboseEcho "Executing Step 6"
        sudo cp /usr/sbin/mopidyctl /usr/sbin/mopidyctl_$i
        sudo sed -i "s/mopidy.conf\"$/mopidy.conf\:\/etc\/mopidy\/mopidy_$i.conf\"/g" /usr/sbin/mopidyctl_$i

        VerboseEcho "Executing Step 7"
        sudo cp /lib/systemd/system/mopidy.service /lib/systemd/system/mopidy_$i.service
        sudo sed -i "s/mopidy.conf$/mopidy.conf\:\/etc\/mopidy\/mopidy_$i.conf/g" /lib/systemd/system/mopidy_$i.service

        VerboseEcho "Executing Step 8"
        #need to check we aren't duplicating stream entries
        if test `sudo grep "pipe:\/\/\/tmp\/snapfifo_$i" /etc/snapserver.conf | wc -l` -eq 0
        then
            sudo sed -i "/\[stream\]/a source = pipe:\/\/\/tmp\/snapfifo_$i?name=Stream_$i" /etc/snapserver.conf
        fi
        i=$(($i + 1))
    done
    VerboseEcho "Enabling all the services"
    i=1
    while [ $i -le $(($numInstance)) ]; do
        sudo systemctl enable mopidy_$i.service
        sudo systemctl start mopidy_$i.service
        i=$(($i + 1))
    done
}
RemoveInstance(){
    numInstance=$((`ls /etc/mopidy/ | wc -l` - 1))
    i=1
    VerboseEcho "Removing $numInstance instances"
    while [ $i -le $(($numInstance)) ]; do
        sudo systemctl stop mopidy_$i.service
        sudo systemctl disable mopidy_$i.service
        sudo rm /lib/systemd/system/mopidy_$i.service
        sudo rm /usr/sbin/mopidyctl_$i
        i=$(($i + 1))
    done
    sudo rm -f /etc/mopidy/mopidy_*.conf
    sudo sed -i "s/^allowed_origins.*//" $coreconfig
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}
TestBaseConfig(){
    host=`sudo grep "^hostname" $coreconfig | sed "s/^[a-zA-Z =]*//g"`
    if test "$host" != ""
    then
        hostname=$host
    else
        echo "[http]" >> $coreconfig
        echo "hostname = $hostname" >> "$coreconfig"
    fi

    VerboseEcho "Checking if snapcast audio config set up"
    audioexists=`sudo grep "^\[audio\]$" $coreconfig `
    if test -z "$audioexists" 
    then
        echo "[audio]" >> $coreconfig
        echo $audioOut >> $coreconfig
    fi
    VerboseEcho "Everything set up alright"
}
coreconfig="/etc/mopidy/mopidy.conf"
numargs=0
#checking to make sure the files are installed
if ! command -v snapserver &> /dev/null
then
    echo "Snapserver isn't installed, please install snapserver"
    exit 1
elif ! command -v mopidy &> /dev/null
then
    echo "Mopidy isn't installed, please install Mopidy"
    exit 1
fi

while getopts ":H:N:O:V:rhv" option; do
    case $option in 
        h)
            Help
        ;;
        H)
            hostname=$OPTARG
        ;;
        N)
            numInstance=$OPTARG
            if test $numInstance -lt 1
            then
                echo "Please specify a number greater than 0"
                exit 1
            fi
        ;;
        O)
            echo "option out"
            if test $OPTARG = "snapcast"
            then
                echo "option out is snapcast"
                audioOut="output = audioresample ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! filesink location=/tmp/snapfifo"
            fi
        ;;
        r)
            removeInstance=true
        ;;
        v)
            verbose=true
        ;;
        i)
            echo "Version 1 of multiple_mopidy.sh"
            exit 0
        ;;
        \?) #invalid option
            echo "Error: invalid option -$OPTARG">&2
            exit 1
        ;;
        :)
            echo "Option -$OPTARG requires an argument.">&2
        ;;
    esac
    numargs=$(($numargs+1))
done

if test $numargs -eq 0
then
    Help
fi


TestBaseConfig
VerboseEcho "removeInstance = $removeInstance"
if test "$removeInstance" = true
then
    RemoveInstance
elif test $numargs -gt 1
then
    echo "creating instance"
    CreateInstance
fi

sudo systemctl restart mopidy.service
sudo systemctl restart snapserver.service
VerboseEcho "Done!"
exit 0