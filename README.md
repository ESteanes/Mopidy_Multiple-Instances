# Making Multiple Mopidy Instances

This script/instruction detials how to create multiple instances of mopidy which pipe their outputs to separate mopidy streams. 

This enables you to have the flexibility to play one song across multiple speakers or have each speaker play its own song. 

### Prerequistes 

* Mopidy installed [Mopidy Github](https://github.com/mopidy/mopidy)
* Snapcast installed [Snapcast Github](https://github.com/badaix/snapcast)

## Automatically

```
$ bash multiple_mopidy.sh <number of instances> <hostname>
```
Note: leaving the hostname blank will result in 127.0.0.1 which means that mopidy will only listen to local requests. Generally unfavourable setup.
## Manually

\<n> represents the number of instances

1. Create additional mopidy_\<n>.conf files
```
$ sudo touch /etc/mopidy/mopidy_<n>.conf
```
2. Using a text editor, edit the file you created and add the following information in your mopdiy_\<n>.conf
```
[core]
cache_dir = /var/cache/mopidy_<n>
data_dir = /var/lib/mopidy_<n>

[http]
port = 668<n>

[audio]
output = audioresample ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! filesink location=/tmp/snapfifo_<n>
```
3. _Optional_ Adding custom settings

You may want to add custom information such as spotify accounts to different mopidy instances as that can help with personalisation. Do that in the corresponding file

For example spotify settings:
```
[spotify]
enabled = true
username = youremail@email.com
password = your_spotify_password
client_id = your_client_id
client_secret = your_client_secret
```

4. Modify the original mopidy.conf file

Add in all the allowed origins for however many mopidy instances you created. This will allow you to access your 2nd mopidy 
```
$ nano /etc/mopidy/mopidy.conf

allowed_origins = <hostname>:6680,<hostname>:668<n> (for all n)
```
5. Create and give ownership of cache and data directoires

If creating multiple directories, can use * wildcard for `chown` command
```
$ mkdir /var/cache/mopdiy_<n>
$ mkdir /var/lib/mopidy_<n>
$ chown mopidy:audio /var/cache/mopidy_<n> /var/lib/mopidy_<n>
```
6. Create copies of the mopidyctl script

Creating copies of the mopidyctl script will enable you to run these mopidy instances as a service without having to manually enable them upon reboot.

```
$ cp /usr/sbin/mopidyctl /usr/sbin/mopdiyctl_<n>
```
Then inside `usr/sbin/mopidyctl_<n>`, change the `CONFIG_FILES` variable to the following:
```
CONFIG_FILES="/usr/share/mopidy/conf.d:/etc/mopidy/mopidy.conf:/etc/mopidy/mopidy_<n>.conf"
```
This will make sure that the service will utilise the appropriate configuration files
unique to the extra instances, overwriting that in the base `mopidy.conf` file with the details in `mopidy_<n>.conf` that you altered previously.

7. Creating additional systemd scripts

You need to create copies of the systemd scripts to activate systemd for all the different instances

```
$ cp /lib/systemd/system/mopidy.service /lib/systemd/system/mopidy_<n>.service
```
Then, using a text editor, edit the `mopidy_<n>.service` file with the following:
```
ExecStart=/usr/bin/mopidy --config /usr/share/mopidy/conf.d:/etc/mopidy/mopidy.conf:/etc/mopidy/mopidy_<n>.conf
```
8. Adding additional streams to Snapcast

Since we are creating multiple instances of mopidy, we need to add these filesink locations in the snapcast configuration file that we are referencing in section 2.

```
$ nano /etc/snapserver.conf
```
then under the `[Stream]` heading, add the following:
```
source = pipe:///tmp/snapfifo_<n>?name=<your custom name>
```
Here you can specify a custom name for each source. You can set up each of the mopidy instances for different people or sections of your house/apartment.

9. Restart all the services

Restart all the services and complete the initialising processes
```
$ systemctl restart snapserver.service
$ mopidyctl_<n> local scan
$ systemctl enable mopidy*.service
$ systemctl start mopidy*.service
