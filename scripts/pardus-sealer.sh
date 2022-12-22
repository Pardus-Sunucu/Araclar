#!/bin/bash

#############################
# Pardus Sealer Script
# Use before convert a Pardus/Linux installation to template 
# brahim ARI <ibrahim.ari@pardus.org.tr>
##############################


# Add users to /etc/sudoers for passwordless sudo
users=("pardus" "admin")

for user in "${users[@]}"
do
  cat /etc/sudoers | grep ^$user
  RC=$?
  if [ $RC != 0 ]; then
    bash -c "echo \"$user ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"
  fi
done

#grab Virtualization type
virt_type=$(systemd-detect-virt)

#update apt-cache
apt-get update

#install packages
if [ $virt_type == "kvm" ]; then
#KVM guest agent
apt-get install -y qemu-guest-agent
elif [ $virt_type == "vmware"]; then
#VmWare Guest Agent
apt-get install -y open-vm-tools
fi

#Stop log services for cleanup
systemctl stop rsyslog.service syslog.socket

#clear audit logs
if [ -f /var/log/audit/audit.log ]; then
    cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
    cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
    cat /dev/null > /var/log/lastlog
fi

#cleanup persistent udev rules
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    rm /etc/udev/rules.d/70-persistent-net.rules
fi

#cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

#cleanup current ssh keys
rm -f /etc/ssh/ssh_host_*

#add check for ssh keys on reboot...and regenerate if neccessary
touch /etc/rc.local
sed -i -e 's|exit 0||' /etc/rc.local
sed -i -e 's|.*test -f /etc/ssh/ssh_host_dsa_key.*||' /etc/rc.local
bash -c 'echo "#!/bin/bash" >> /etc/rc.local'
bash -c 'echo "test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server" >> /etc/rc.local'
bash -c 'echo "exit 0" >> /etc/rc.local'
chmod a+x /etc/rc.local

# Flush All ARP Cache
ip -s -s neigh flush all

#reset hostname, and set to localhost.localdomain
cat /dev/null > /etc/hostname
echo "localhost.localdomain" > /etc/hostname

#cleanup apt
apt-get clean
#cleanup shell history
history -w
history -c
