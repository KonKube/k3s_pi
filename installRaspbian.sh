#!/bin/bash
# ./installRaspbian.sh k3s-master /dev/sdb Europe/Berlin sender@gmail recipient@gmail
# ./installRaspbian.sh k3s-node-0 /dev/sdb Europe/Berlin sender@gmail recipient@gmail 192.168.1.100 TOKEN

set -e
set -o pipefail

HOSTNAME=$1
FILESYSTEM=$2
TIMEZONE=$3
MAIL_SENDER=$4
MAIL_RECIPIENT=$5
K3S_MASTER_IP=$6
NODE_TOKEN=$7

IMAGE=raspbian.img
ROOT_FS_PATH=/media/`whoami`/rootfs
BOOT_FS_PATH=/media/`whoami`/boot

if [[ ! -f "$IMAGE" ]]
then
  echo "downloads $IMAGE image"
  curl -LO https://downloads.raspberrypi.org/raspbian_lite_latest
  unzip -o raspbian_lite_latest
  mv *.img raspbian.img
  rm -f raspbian_lite_latest
else
  echo "image $IMAGE exists"
fi

if mountpoint -x $FILESYSTEM > /dev/null 2>&1
then
  echo "creating filesystem on $FILESYSTEM with image $IMAGE"
  sudo dd bs=1M if=$IMAGE of=$FILESYSTEM status=progress
  if [ $? -eq 0 ]
  then
    echo "creating filesystem from image $IMAGE was successful"
  else
    echo "creating filesystem from image $IMAGE failed"
    exit 1
  fi
else
  echo "filesystem $FILESYSTEM does not exists"
  exit 1
fi

if mountpoint -x $FILESYSTEM\2
then
  if mountpoint -q $ROOT_FS_PATH
  then
    echo "rootfs filesystem path $ROOT_FS_PATH is mounted"
    echo "unmount $ROOT_FS_PATH"
    sudo umount $ROOT_FS_PATH
  fi
  echo "fix rootfs $ROOT_FS_PATH with fsck"
  sudo fsck -y $FILESYSTEM\2
  echo "successful fixed $ROOT_FS_PATH"
fi

if [[ -d $ROOT_FS_PATH ]]
then
  echo "rootfs mount path $ROOT_FS_PATH exists"
  if mountpoint -q $ROOT_FS_PATH
  then
    echo "rootfs mount path $ROOT_FS_PATH is mounted"
  else
    echo "mount filesystem to $ROOT_FS_PATH"
    sudo mount $FILESYSTEM\2 $ROOT_FS_PATH
  fi
else
  echo "rootfs mount path $ROOT_FS_PATH does not exists"
  echo "creating missing path $ROOT_FS_PATH"
  sudo mkdir $ROOT_FS_PATH
  echo "mount filesystem to $ROOT_FS_PATH"
  sudo mount $FILESYSTEM\2 $ROOT_FS_PATH
fi

if mountpoint -x $FILESYSTEM\1
then
  if mountpoint -q $BOOT_FS_PATH
  then
    echo "boot filesystem path $BOOT_FS_PATH is mounted"
    echo "unmount $BOOT_FS_PATH"
    sudo umount $BOOT_FS_PATH
  fi
  echo "fix boot $BOOT_FS_PATH with fsck"
  sudo fsck -y $FILESYSTEM\1
  echo "successful fixed $BOOT_FS_PATH"
fi

if [[ -d $BOOT_FS_PATH ]]
then
  echo "boot mount path $BOOT_FS_PATH exists"
  if mountpoint -q $BOOT_FS_PATH
  then
    echo "boot mount path $BOOT_FS_PATH is mounted"
  else
    echo "mount filesystem to $BOOT_FS_PATH"
    sudo mount $FILESYSTEM\1 $BOOT_FS_PATH
  fi
else
  echo "boot mount path $BOOT_FS_PATH does not exists"
  echo "creating missing path $BOOT_FS_PATH"
  sudo mkdir $BOOT_FS_PATH
  echo "mount filesystem to $BOOT_FS_PATH"
  sudo mount $FILESYSTEM\1 $BOOT_FS_PATH
fi

if [[ -d $ROOT_FS_PATH ]]
then
  if [[ -f ./wpa_supplicant.conf ]]
  then
    echo "adding wpa_supplicant.conf to $ROOT_FS_PATH/etc/wpa_supplicant/wpa_supplicant.conf"
    cat wpa_supplicant.conf | sudo tee -a $ROOT_FS_PATH/etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
  fi

  echo "set hostname to $HOSTNAME"
  echo $HOSTNAME | sudo tee $ROOT_FS_PATH/etc/hostname > /dev/null

  echo "set hostname to localhost in /etc/hosts"
  echo "127.0.1.1       $HOSTNAME" | sudo tee -a $ROOT_FS_PATH/etc/hosts

  echo "set local time to $TIMEZONE"
  sudo rm $ROOT_FS_PATH/etc/localtime
  sudo cp $ROOT_FS_PATH/usr/share/zoneinfo/$TIMEZONE $ROOT_FS_PATH/etc/localtime

  if [[ -f ~/.ssh/id_rsa.pub ]]
  then
    echo "adding ~/.ssh/id_rsa.pub and deactivating password authentication"
    sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/g' $ROOT_FS_PATH/etc/ssh/sshd_config
    sudo sed -i 's/^UsePAM yes/UsePAM no/g' $ROOT_FS_PATH/etc/ssh/sshd_config
    if [[ ! -d "$ROOT_FS_PATH/home/pi/.ssh" ]]
    then
      echo "creating $ROOT_FS_PATH/home/pi/.ssh directory"
      sudo mkdir $ROOT_FS_PATH/home/pi/.ssh
      sudo chown 1000:1000 $ROOT_FS_PATH/home/pi/.ssh
    fi
    sudo cp -a ~/.ssh/id_rsa.pub $ROOT_FS_PATH/home/pi/.ssh/authorized_keys
  fi

  if [[ -f $ROOT_FS_PATH/etc/sudoers ]]
  then
    echo "giving sudo privileges to user pi"
    echo "pi ALL=(ALL) NOPASSWD:ALL" | sudo tee -a $ROOT_FS_PATH/etc/sudoers > /dev/null
  fi

  if [[ $HOSTNAME =~ "master" ]]
  then
    if [[ -f ./installMaster.sh ]]
    then
      echo "adding installMaster.sh to $ROOT_FS_PATH/home/pi/installMaster.sh"
      cp ./installMaster.sh $ROOT_FS_PATH/home/pi/installMaster.sh
      sudo chmod 755 $ROOT_FS_PATH/home/pi/installMaster.sh
      echo "@reboot ~/installMaster.sh $HOSTNAME $MAIL_SENDER"  | sudo tee -a $ROOT_FS_PATH/var/spool/cron/crontabs/pi
      sudo chown 1000:crontab $ROOT_FS_PATH/var/spool/cron/crontabs/pi
      sudo chmod 600 $ROOT_FS_PATH/var/spool/cron/crontabs/pi
    else
      echo "./installMaster.sh is missing"
    fi
  elif [[ $HOSTNAME =~ "node" ]]
  then
    if [[ -f ./installNode.sh ]]
    then
      echo "adding installNode.sh to $ROOT_FS_PATH/home/pi/installNode.sh"
      cp ./installNode.sh $ROOT_FS_PATH/home/pi/installNode.sh
      sudo chmod 755 $ROOT_FS_PATH/home/pi/installNode.sh
      echo "@reboot ~/installNode.sh $HOSTNAME $MAIL_SENDER $NODE_TOKEN"  | sudo tee -a $ROOT_FS_PATH/var/spool/cron/crontabs/pi
      sudo chown 1000:crontab $ROOT_FS_PATH/var/spool/cron/crontabs/pi
      sudo chmod 600 $ROOT_FS_PATH/var/spool/cron/crontabs/pi
      if [[ -v K3S_MASTER_IP ]]
      then
        echo "adding k3s-master to /etc/hosts with the IP $K3S_MASTER_IP"
        echo "$K3S_MASTER_IP       k3s-master" | sudo tee -a $ROOT_FS_PATH/etc/hosts
      else
        echo "K3S_MASTER_IP value is missing"
      fi
    else
      echo "./installNode.sh is missing"
    fi

  else
    echo "wrong hostname. Must contain master or node to define the kubernetes cluster role"
  fi

  if [[ -f ./ssmtp.conf && -f ./mail.sh && -v MAIL_RECIPIENT ]]
  then
    echo "adding ssmtp.conf and mail.sh to $ROOT_FS_PATH/home/pi/"
    cp ./ssmtp.conf $ROOT_FS_PATH/home/pi/ssmtp.conf
    sudo chmod 755 $ROOT_FS_PATH/home/pi/ssmtp.conf
    cp ./mail.sh $ROOT_FS_PATH/home/pi/mail.sh
    sudo chmod 755 $ROOT_FS_PATH/home/pi/mail.sh
    echo "adding mail notification for reboots and daily heartbeats"
    echo "@reboot ~/mail.sh $MAIL_RECIPIENT REBOOT-$HOSTNAME"  | sudo tee -a $ROOT_FS_PATH/var/spool/cron/crontabs/pi
    echo "0 16 * * * ~/mail.sh $MAIL_RECIPIENT HEARTBEAT-$HOSTNAME"  | sudo tee -a $ROOT_FS_PATH/var/spool/cron/crontabs/pi
  fi
else
  echo "could not find $ROOT_FS_PATH"
fi

if [[ -d $BOOT_FS_PATH ]]
then
  if [[ ! -f "$BOOT_FS_PATH/ssh" ]]
  then
    echo "enabling ssh login"
    sudo touch $BOOT_FS_PATH/ssh
  fi

  echo "set cgroup_enable for cpu and memory"
  echo -n ' cgroup_enable=cpuset cgroup_enable=memory' | sudo tee -a $RPMOUNTPATH/cmdline.txt
  sudo sh -c "tr -d '\n' < $RPMOUNTPATH/cmdline.txt > $RPMOUNTPATH/cmdline2.txt"
  sudo mv $RPMOUNTPATH/cmdline2.txt $RPMOUNTPATH/cmdline.txt
else
  echo "could not find $BOOT_FS_PATH"
fi

sleep 10
echo "removes mounts"
sudo umount $ROOT_FS_PATH
sudo umount $BOOT_FS_PATH
sleep 10
echo "removes mountpoints"
sudo rm -rf $ROOT_FS_PATH
sudo rm -rf $BOOT_FS_PATH
echo "finished!"
