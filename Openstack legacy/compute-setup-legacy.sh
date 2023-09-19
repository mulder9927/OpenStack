#!/bin/bash

#This script will (hopefully) create a working compute node
#This masterpiece was created by the one and only
#Paul Wilson
#6-29-2020

#~~to my lovely servers, may you still run far after i am dust.~~

#TODO SET password values from file or array or something idk
#TODO, Check drive Configuration

#list of passwords. TODO add them to a file and move them out of this Description
rabbitpass="b36cffb9c761c9337af8"
cinderDBpass="0848d603844c21542ee1"
cinderpass="507bc3db233b33ab0467"
novapass="cb7f121ddb363fc84fc3"
neutronpass="7822615b71c66e844661"
placementpass="df218651c3ef7e252321"

#script must run as root
#...
FILE="/tmp/out.$$"
GREP="/bin/grep"
if [[ $EUID -ne 0 ]]; then
  echo "this must be run as root user, exiting" 1>&2
  exit 1
fi
#...
#logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

#Clear screen for readability ~~~ do this more paul!
clear >$(tty)
#welcome to the compute script
printf "hello fellow human, please enjoy these prerequisites.\nif you pass this test you will reach the automated openstack legacy installation script\nalso known as OLIS."

#check locale and set if needed
loc=$(localectl status | grep Locale)
if [ $loc  == System Locale: LANG=en_US.UTF-8 ]
then
  echo "Locale is correct"
else
  localectl set-locale LANG=en_US.UTF-8
fi
#check timezone and set if needed
tzo=$(cat /etc/timezone)
if [[ $tzo == America/Los_Angeles ]]
then
  echo "Time zone is correct"
  clear >$(tty)
else
  timedatectl set-timezone "America/Los_Angeles"
fi

#Setting up user and group permissions
addgroup --system lpadmin
addgroup --system sambashare
clear >$(tty)
#check for username
if id "mwsadmin" $>/dev/null; then
  echo "user is on compute"
else
  adduser mwsadmin
  chown -R mwsadmin:mwsadmin /home/mwsadmin
  cp -a /etc/skel/.[!.]* /home/mwsadmin
fi
permcheck=$(id mwsadmin)
if [[ $permcheck == "uid=1000(mwsadmin) gid=1000(mwsadmin) groups=1000(mwsadmin),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),108(lxd),117(libvirt)" ]]; then
  echo "ok, permissions are good"

else
  usermod -aG adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo mwsadmin
fi

#read the rack number in with error checking
clear >$(tty)
echo "what are you setting up?"
options=(compute controller)
select menu in "${options[@]}";
do
  if [[ $menu == compute ]]; then
    echo "Ok, you are in the right place. which Rack is is this going in?"
    while [[ 1=$cv ]]; do
      read rackval; if ! [[ $rackval == [0-9] ]]; then echo "sorry please input a valid rack number"; else  echo "ok, that is a number your rack from now on is rack $rackval";break; fi; done; break;
    else  echo "Ok, hate to be that guy but this is not the script for you. BYEEEE"
      exit
    fi
  done

  clear >$(tty)


  hostn=$(cat /etc/hostname)

  #Confirm hostname status
  echo "Current hostname of this device is $hostn"
  while [ 1=$o ]; do
    read -p "Do you want to change the name of the device? y/n: " yn
    case $yn in
      [Yy]* )
      #read the comp number in with error checking
      while [[ 1=$cc ]]; do
        clear >$(tty)
        echo "please input a compute number for this new compute MAKE SURE ITS DIFFERENT FROM EXISTING COMPUTES"
        read compval; if ! [[ $compval == [0-9] ]]; then echo "sorry please input a valid compute number"; else  echo "ok, that is a number your compute from now on is compute$compval"; break; fi; done;

        #read the asset tag
        while [[ 1=$cat ]]; do
          printf "please input the asset tag for this compute If you dont have one then you arent doing it right.\n\e[31m go to the inventory system before i delete your access.\e[0m\n:"
          read asset;
          read -r -p "The asset name you entered is $asset, is this correct?" resp; if [[ $resp =~ ^([yY][eE][sS]|[yY])$ ]]; then break; else echo "retying"; fi;
        done

        #make sure that all the info is correct.
        #change hostname
        while true; do
          clear >$(tty)
          printf "double checking, the hosname you want for this compute is \e[31m r$rackval-compute$compval-$asset \e[0m correct?\n and one with this name doesnt exist? "
          read -p "do you want to continue? Y/N:" yn
          case $yn in
            [Yy]* ) fullname=$(echo "r"$rackval"-compute"$compval"-"$asset); break;;
            [Nn]* ) exit;;
          esac
        done
        break;;
        [Nn]* ) clear >$(tty); read -t 3 -p "no change is requested hostname will remain $hostn"; fullname=$(echo "$hostn") break;;
      esac
    done

    mv /etc/hostname /etc/hostname.old

#change hostname
cat << EOF > /etc/hostname

  $fullname

EOF

    #Clear screen for readability
    clear >$(tty)

    echo "just to make sure this works i need to know if you have internets"

    #check for internet connection
    nc -z 8.8.8.8 53  >/dev/null 2>&1
    online=$?
    if [ $online -eq 0 ]; then
      echo "you has the internets"
      clear >$(tty)
    else
      echo "OOPSIE, no internet. do you want to continue with this and let it yell and break or do you want to exit this script and fix the server first?"
      options=(I_know_what_I_am_doing Save_me_from_myself)
      select menu in "${options[@]}";
      do
        if [[ $menu == I_know_what_I_am_doing ]]; then
          echo "I got this bro";
          break
        else
          echo "im a noob and dont wanna get fired";
          exit
        fi
      done
    fi


printf "This computer will be using 2 network connections. \nThe legacy compute uses only 2 network connections."
#iterates the array to read the network interfaces
  netwarr=$()
#read the network interfaces into an array
for inet in $(ip -o link show | awk -F': ' '{print $2}')
do
    netwarr+=("$inet")
done
#asking you the important questions
while true; do
  echo "please select network interface #1 below."
  select intface in ${netwarr[@]}; do
 netport1=("$intface")
  echo "Network interface 1 is now $netport1"
 break
done
 echo "please select network interface #2 below."
  select intface in ${netwarr[@]}; do
  netport2=("$intface")
  echo "Network interface 2 is now $netport2"
  break
done
read -p "are the following Interface numbers correct? Interface 1 is $netport1 and Interface 2 is $netport2 Y/N: " resp; if [[ $resp =~ ^([yY][eE][sS]|[yY])$ ]]; then break; else echo "retying"; fi
  done

clear >$(tty)
  #function to get the ip address from the user
  while true; do
    echo "enter computes last octec X.X.X.THISNUMBER IP address: "; read ipval
    if [[ $ipval =~ ^[0-9]{1,3}$ ]]; then
      echo "ok, cool $ipval is a valid ip"
      read -p "your compute will now be IP: 10.1.$rackval.$ipval is this ok? Y-N: " resp; if [[ $resp =~ ^([yY][eE][sS]|[yY])$ ]]; then netvalue=$(echo "10.1.$rackval.$ipval"); break; else echo "retying"; fi
    else
      echo "thats not a cool ip bruh why dont you try a 3 digit number again:"
    fi
  done

clear >$(tty)
echo "Writing the network config file. if you need to fix anything do it before final conformation."

mv /etc/network/interfaces /etc/network/interfaces.old


cat << EOF > /etc/network/interfaces
auto $netport1
iface $netport1 inet static
address 10.1.$rackval.$ipval
netmask 255.255.255.0
gateway 10.1.$rackval.5
up ip link set dev \$IFACE up
down ip link set dev \$IFACE down


auto $netport2
iface $netport2 inet manual
up ip link set dev \$IFACE up
down ip link set dev \$IFACE down
EOF


    #Clear screen for readability
    clear >$(tty)
lsblk
echo "above are all available drives"
#gettign drive preference info
while [[ 1=$cat ]]; do
  printf "please input the drive you want for cinder on this compute If you dont have one then you arent doing it right.\n\e[31m EX: md0 you do not need to put /dev/ \e[0m\n:"
  read cinddriveval;
  read -r -p "The drivename you entered is $cinddriveval, is this correct? Y/N:" resp; if [[ $resp =~ ^([yY][eE][sS]|[yY])$ ]]; then break; else echo "retying"; fi;
done
clear >$(tty)

#get the controller mname
#gettign drive preference info
while [[ 1=$cat ]]; do
  printf "please input the name of the controller for this openstack rack .\n\e[31m EX: r1-controller \e[0m\n:"
  read controllername;
  read -r -p "The controller name you entered is $controllername, is this correct? Y/N:" resp; if [[ $resp =~ ^([yY][eE][sS]|[yY])$ ]]; then break; else echo "retying"; fi;
done

#setting host FILE
mv /etc/hosts /etc/hosts.old

cat << EOF > /etc/hosts
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# Reference /etc/hosts.old for more settings

10.1.$rackval.40 $controllername
10.1.$rackval.$ipval $fullname
#put future computes above this line

127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF





clear >$(tty)
    echo "the prerequisites are satisfied, you made it!"

    #Say cool things to make people happy you can hello world
    echo "Welcome to the Openstack Controller Configuration wizard."

    #Ask the user if they know what they are doing.
    while true; do
      printf "You will be installing the following .\n\e[31m $fullname into rack $rackval \e[0m\n under controller .\n\e[31m$controllername\e[0m\n \nif you do not want to continue select no and exit\n"
      read -p "do you want to continue y/n: ?" yn
      case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
      esac
    done

    echo "Ok, here we go. Checking version and software status. please wait."

    #check the OS version to make sure this script may work
    osversion=$(lsb_release -a 2>/dev/null | grep Description)
    if [[ $osversion  == *"Ubuntu 18.04"* ]]
    then
      echo "Moving forward with the script, this is a known and supported OS"
    else
      while true; do
        echo "ok, I am not sure if this will work, or if its been tested my check function on line 42 needs to be revisited.. \nbut if you think were good then im down for whatever."
        read -p " your OS version is $osversion do you want to continue y/n: ?" yn
        case $yn in
          [Yy]* ) break;;
          [Nn]* ) echo "OK, try again later or idk like fix me or something"; exit;;
        esac
      done
    fi


    echo "updating all the programs and such standby"
    add-apt-repository cloud-archive:rocky
    apt update
    apt upgrade -y
    echo "checking for installed programs relating to openstack compute legacy configuration"
    #add-apt-repository cloud-archive:rocky

    missarr=$()
    insarr=$()

    #for i in chrony netplan.io ifupdown software-properties-common python-openstackclient mariadb-server python-pymysql rabbitmq-server memcached python-memcache etcd keystone apache2 libapache2-mod-wsgi glance nova-api nova-conductor nova-consoleauth nova-scheduler nova-placement-api neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent openstack-dashboard cinder-api cinder-scheduler smartmontools
    for i in chrony netplan.io ifupdown software-properties-common lvm2 thin-provisioning-tools nova-compute neutron-linuxbridge-agent cinder-volume smartmontools
    do
      isinstalled=$(apt list -a $i 2>/dev/null | grep -o installed)
      pname=$(apt list -a $i 2>/dev/null | grep installed | grep -o $i)

      if [ -z $isinstalled ]; then
        mname=$(apt list -a $i 2>/dev/null | grep -o $i | head -1)
        #setting the array for the missing appliations
        missarr+=("$mname")
      else
        #setting the array with the name of the package
        insarr+=("$pname")
      fi
    done
clear >$(tty)
    for value in "${missarr[@]}"
    do
      echo "$value"
    done
    #Function to install the missing packages.
    echo "Above is listed any missing packages: [yn]" yn
    while true; do
      read -p "do you wanna install the missing packages??" yn
      case $yn in
        [Yy]* )for o in "${missarr[@]}";
        do
          echo "Installing the package $o"
          apt install $o -y
        done
        break;;
        [Nn]* )echo "mmnkay i wont bother you about it i hope you know what youre doing brother..."
        break;;
      esac
    done

#setup cinder volumes
vgcreate cinder-volumes /dev/$cinddriveval

cp /etc/lvm/vlm.conf /etc/lvm/lvm.old

cat << EOF > /etc/lvm/lvm.conf
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# Reference /etc/lvm/lvm.old for more settings

config {

	checks = 1

	abort_on_errors = 0

	profile_dir = "/etc/lvm/profile"
}

devices {

	dir = "/dev"

	scan = [ "/dev" ]

	obtain_device_list_from_udev = 1

	external_device_info_source = "none"

	filter = [ "a/md0/", "r/.*/"]

	cache_dir = "/run/lvm"

	cache_file_prefix = ""

	write_cache_state = 1

	sysfs_scan = 1

	multipath_component_detection = 1

	md_component_detection = 1

	fw_raid_component_detection = 0

	md_chunk_alignment = 1

	data_alignment_detection = 1

	data_alignment = 0

	data_alignment_offset_detection = 1

	ignore_suspended_devices = 0

	ignore_lvm_mirrors = 1

	disable_after_error_count = 0

	require_restorefile_with_uuid = 1

	pv_min_size = 2048

	issue_discards = 1

	allow_changes_with_duplicate_pvs = 0
}

allocation {

	maximise_cling = 1

	use_blkid_wiping = 1

	wipe_signatures_when_zeroing_new_lvs = 1

	mirror_logs_require_separate_pvs = 0

	cache_pool_metadata_require_separate_pvs = 0

	thin_pool_metadata_require_separate_pvs = 0

}

log {

	verbose = 0

	silent = 0

	syslog = 1

	overwrite = 0

	level = 0

	indent = 1

	command_names = 0

	prefix = "  "

	activation = 0

	debug_classes = [ "memory", "devices", "activation", "allocation", "lvmetad", "metadata", "cache", "locking", "lvmpolld", "dbus" ]
}

backup {

	backup = 1

	backup_dir = "/etc/lvm/backup"

	archive = 1

	archive_dir = "/etc/lvm/archive"

	retain_min = 10

	retain_days = 30
}

shell {

	history_size = 100
}

global {

	umask = 077

	test = 0

	units = "r"

	si_unit_consistency = 1

	suffix = 1

	activation = 1

	proc = "/proc"

	etc = "/etc"

	locking_type = 1

	wait_for_locks = 1

	fallback_to_clustered_locking = 1

	fallback_to_local_locking = 1

	locking_dir = "/run/lock/lvm"

	prioritise_write_locks = 1

	abort_on_internal_errors = 0

	detect_internal_vg_cache_corruption = 0

	metadata_read_only = 0

	mirror_segtype_default = "raid1"

	raid10_segtype_default = "raid10"

	sparse_segtype_default = "thin"

	use_lvmetad = 1

	use_lvmlockd = 0

	system_id_source = "none"

	use_lvmpolld = 1

	notify_dbus = 1
}

activation {

	checks = 0

	udev_sync = 1

	udev_rules = 1

	verify_udev_operations = 0

	retry_deactivation = 1

	missing_stripe_filler = "error"

	use_linear_target = 1

	reserved_stack = 64

	reserved_memory = 8192

	process_priority = -18

	raid_region_size = 2048

	readahead = "auto"

	raid_fault_policy = "warn"

	mirror_image_fault_policy = "remove"

	mirror_log_fault_policy = "allocate"

	snapshot_autoextend_threshold = 100

	snapshot_autoextend_percent = 20

	thin_pool_autoextend_threshold = 100

	thin_pool_autoextend_percent = 20

	use_mlockall = 0

	monitoring = 1

	polling_interval = 15

	activation_mode = "degraded"

}

dmeventd {

	mirror_library = "libdevmapper-event-lvm2mirror.so"

	snapshot_library = "libdevmapper-event-lvm2snapshot.so"

	thin_library = "libdevmapper-event-lvm2thin.so"

}
EOF

#start the actual configuration functions
clear >$(tty)
echo "ok, packages should be installed so lets get to cooking."
read -t 5 -p "Read all instructions carefully!"

#setup resolved
mv /etc/systemd/resolved.conf  /etc/systemd/resolved.oslo_middleware

cat << EOF >  /etc/systemd/resolved.conf
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# Reference /etc/systemd/resolved.old for full file examples
[Resolve]
DNS=10.1.$rackval.40 8.8.8.8
EOF


mv /etc/chrony/chrony.conf /etc/chrony/chrony.old
#chrony configuration
cat << EOF > /etc/chrony/chrony.conf
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# reference /etc/chrony/chrony.old for full file examples
  server $controllername iburst
  keyfile /etc/chrony/chrony.keys
  driftfile /var/lib/chrony/chrony.drift
  logdir /var/log/chrony
  maxupdateskew 100.0
  rtcsync
  makestep 1 3

EOF

#nova Configuration
mv /etc/nova/nova.conf /etc/nova/nova.old

cat << EOF > /etc/nova/nova.conf
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# reference /etc/nova/nova.old for full file examples

[DEFAULT]
transport_url = rabbit://openstack:$rabbitpass@$controllername
my_ip = $netvalue
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
log_dir = /var/log/nova
lock_path = /var/lock/nova
state_path = /var/lib/nova
block_device_allocate_retries = 600
block_device_allocate_retries_interval = 3

[api]
auth_strategy = keystone

[api_database]
connection = sqlite:////var/lib/nova/nova_api.sqlite

[barbican]

[cache]

[cells]
enable = False

[cinder]

[compute]

[conductor]

[console]

[consoleauth]

[cors]

[database]
connection = sqlite:////var/lib/nova/nova.sqlite

[devices]

[ephemeral_storage_encryption]

[filter_scheduler]

[glance]
api_servers = http://$controllername:9292

[guestfs]

[healthcheck]

[hyperv]

[ironic]

[key_manager]

[keystone]

[keystone_authtoken]
auth_url = http://$controllername:5000/v3
memcached_servers = $controllername:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = $novapass

[libvirt]
images_type = lvm
images_volume_group = cinder-volumes

[matchmaker_redis]

[metrics]

[mks]

[neutron]
url = http://$controllername:9696
auth_url = http://$controllername:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $neutronpass

[notifications]

[osapi_v21]

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[oslo_messaging_amqp]

[oslo_messaging_kafka]

[oslo_messaging_notifications]

[oslo_messaging_rabbit]

[oslo_messaging_zmq]

[oslo_middleware]

[oslo_policy]

[pci]

[placement]
os_region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://$controllername:5000/v3
username = placement
password = $placementpass

[placement_database]

[powervm]

[profiler]

[quota]

[rdp]

[remote_debug]

[scheduler]

[serial_console]

[service_user]

[spice]

[upgrade_levels]

[vault]

[vendordata_dynamic_auth]

[vmware]

[vnc]
enabled = True
server_listen = 0.0.0.0
server_proxyclient_address = \$my_ip
novncproxy_base_url = http://$controllername:6080/vnc_auto.html

[workarounds]

[wsgi]

[xenserver]

[xvp]

[zvm]

EOF

#systemctl restart nova-compute

#write the neutron configuration
mv /etc/neutron/neutron.conf /etc/neutron/neutron.old

cat << EOF > /etc/neutron/neutron.conf
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# reference /etc/neutron/neutron.old for full file examples

[DEFAULT]
transport_url = rabbit://openstack:$rabbitpass@$controllername
auth_strategy = keystone
core_plugin = ml2

[agent]
root_helper = "sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf"

[cors]

[database]
connection = sqlite:////var/lib/neutron/neutron.sqlite

[keystone_authtoken]
www_authenticate_uri = http://$controllername:5000
auth_url = http://$controllername:5000
memcached_servers = $controllername:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $neutronpass

[matchmaker_redis]

[nova]

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp

[oslo_messaging_amqp]

[oslo_messaging_kafka]

[oslo_messaging_notifications]

[oslo_messaging_rabbit]

[oslo_messaging_zmq]

[oslo_middleware]

[oslo_policy]

[quotas]

[ssl]


EOF

#setup ml2 plugin
#write the neutron configuration
mv /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.old

cat << EOF > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# reference /etc/neutron/plugins/ml2/linuxbridge_agent.old for full file examples

[DEFAULT]

[agent]

[linux_bridge]
physical_interface_mappings = provider:$netport2

[network_log]

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

[vxlan]
enable_vxlan = true
local_ip = 10.1.$rackval.$ipval
l2_population = true

EOF

#systemctl restart nova-compute
#systemctl restart neutron-linuxbridge-agent

#setup cinder configs
mv /etc/cinder/cinder.conf /etc/cinder/cinder.old

cat << EOF > /etc/cinder/cinder.conf
# This Config was written automatically by the compute install script
# Paul Wilson made this, blame him.
# config for chrony
# This was ran on $fullname
# reference /etc/cinder/cinder.old for full file examples

[DEFAULT]
rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper = tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
state_path = /var/lib/cinder
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes
enabled_backends = lvm
transport_url = rabbit://openstack:$rabbitpass@$controllername
auth_strategy = keystone
my_ip = 10.1.$rackval.$ipval
enabled_backends = lvm
glance_api_servers = http://$controllername:9292

[database]
connection = mysql+pymysql://cinder:$cinderDBpass@$controllername/cinder
#connection = sqlite:////var/lib/cinder/cinder.sqlite

#below groups added manually
[keystone_authtoken]
auth_uri = http://$controllername:5000
auth_url = http://$controllername:5000
memcached_servers = $controllername:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $cinderpass

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp

EOF

#systemctl restart tgt
#systemctl restart cinder-volume


echo "cleaning up"


apt -y purge netplan.io
systemctl enable networking

clear >$(tty)

echo "Ok, $fullname is setup and should be ready for adoption."
echo "when you exit this script you should only need to do the following"
echo "1. Check the hosts file to make sure all needed entries are there"
echo "2. Double check the config data"
echo "3. Reboot the computer and put it into the controllers network (so it can see the controller)"
echo "good luck"
read -p "press any key to exit"
