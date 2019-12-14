#!/bin/bash

set -e

HOSTNAME=$1
MAIL_RECIPIENT=$2

if [[ ! -f ~/initial.lock ]]
then

  # initialize locales
  echo "initialize locales"
  export LANGUAGE=en_GB.UTF-8
  export LANG=en_GB.UTF-8
  export LC_ALL=en_GB.UTF-8
  sudo /usr/sbin/locale-gen en_GB.UTF-8

  # initial update and upgrade on first boot
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

  if [[ -f ~/.msmtprc ]] && [[ -f ~/mail.sh ]]
  then
    # install email resources
    echo "install msmtp and mailutils"
    sudo apt-get -y install \
      msmtp \
      msmtp-mta \
      mailutils
  fi

  # disable swap
  sudo dphys-swapfile swapoff
  sudo dphys-swapfile uninstall
  sudo systemctl disable dphys-swapfile

  # install k3s
  curl -sfL https://get.k3s.io -o install.sh
  chmod 755 install.sh
  ./install.sh server --kubelet-arg="address=0.0.0.0"

  # sleep for startup of k3s
  sleep 300

  # configure master node role and node label
  #sudo kubectl taint nodes $HOSTNAME node-role.kubernetes.io/master=true:NoSchedule

  # create initial.lock
  echo "create initial.lock"
  if [[ -f ~/.msmtprc ]] && [[ -f ~/mail.sh ]] && [[ ! -z "$MAIL_RECIPIENT" ]]
  then
    ~/mail.sh $MAIL_RECIPIENT InitialSetup-$HOSTNAME-Successful
  fi
  touch ~/initial.lock
  sudo reboot now
fi
