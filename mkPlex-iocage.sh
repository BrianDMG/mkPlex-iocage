#!/bin/bash
#iocage Plex jail creation script

#User-defined vars
version='11.2-RELEASE'
name='plex'
plexpass=true
pkglist='plexpkglist'
notes='Plex: A media server application'
#If set to true, specify the proper paths below to create mount points, otherwise set as false
mount_movies=true
mount_tv=true
mount_music=true
#Put your desired MAC address here (useful for DHCP reservations)
macaddr='01234567890a'
#Should point to a dataset in a volume where Tautulli db/files will be stored outside of the jail
plexdata_mount_src='/path/on/volume/to/plexdataset'
#Path to Plex db/metadata in the jail, don't change unless you know what you're doing
plexdata_mount_dest='/usr/local/plexdata-plexpass'
movie_mount_src='/path/on/volume/to//movies'
movie_mount_dest='/path/in/jail/to/movies'
tv_mount_src='/path/on/volume/to//tv'
tv_mount_dest='/path/in/jail/to/tv'
music_mount_src='/path/on/volume/to//music'
music_mount_dest='/path/in/jail/to/music'

#Install plexmediaserver
if [ "$plexpass" == "true" ]; then
    echo '{"pkgs":["plexmediaserver-plexpass"]}' > /tmp/$pkglist
else
    echo '{"pkgs":["plexmediaserver"]}' > /tmp/$pkglist
fi

#Create the jail
iocage create -r $version -n $name -p /tmp/$pkglist vnet='on' host_hostname="$name" boot='on' notes="$notes" \
	interfaces='vnet0:bridge0' dhcp='on' vnet0_mac="$macaddr" bpf='yes'

#Cleanup temp file
rm -f /tmp/$pkglist

#Enable Plex on boot and start the service
if [ "$plexpass" == "true" ]; then
    iocage exec $name "pkg update && pkg upgrade; \
	    printf '\n#Plex Media Server\nplexmediaserver_plexpass_enable=\"YES\"\n' >> /etc/rc.conf; \
	    service plexmediaserver_plexpass start"
else
    iocage exec $name "pkg update && pkg upgrade; \
	    printf '\n#Plex Media Server\nplexmediaserver_enable=\"YES\"\n' >> /etc/rc.conf; \
	    service plexmediaserver start"
fi

#Stop jail to add mount points
iocage stop $name

#Mount Plex dataset on volume to plexdata dir in jail
iocage fstab -a $name "$plexdata_mount_src $plexdata_mount_dest nullfs ro 0 0"

#Create media mount points
if [ "$mount_movies" == "true" ]; then iocage fstab -a $name "$movie_mount_src $movie_mount_dest nullfs rw 0 0"; fi
if [ "$mount_tv" == "true" ]; then iocage fstab -a $name "$tv_mount_src $tv_mount_dest nullfs rw 0 0"; fi
if [ "$mount_music" == "true" ]; then iocage fstab -a $name "$music_mount_src $music_mount_dest nullfs rw 0 0"; fi

#Change pkg to use the latest releases instead of quarterly, update pkg repo and upgrade existing pkgs, add rad motd
iocage exec $name "sed -i '' 's/quarterly/latest/' /etc/pkg/FreeBSD.conf; \
	pkg update && pkg upgrade -y; \
	tee /etc/motd << 'EOF'
 ______   __         ______     __  __    
/\  == \ /\ \       /\  ___\   /\_\_\_\   
\ \  _-/ \ \ \____  \ \  __\   \/_/\_\/_  
 \ \_\    \ \_____\  \ \_____\   /\_\/\_\ 
  \/_/     \/_____/   \/_____/   \/_/\/_/ 
                                          
EOF"