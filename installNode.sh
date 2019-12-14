#!/bin/bash

set -e

HOSTNAME=$1
MASTERDN=$2
NODE_TOKEN=$3
MAIL_RECIPIENT=$4

if [[ ! -f ~/initial.lock ]]
then

  # initialize locales
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

  # install k3s
  curl -sfL https://get.k3s.io -o install.sh
  chmod 755 install.sh
  ./install.sh agent --server https://$MASTERDN:6443 --kubelet-arg="address=0.0.0.0" --token $NODE_TOKEN

  # sleep for startup of k3s
  sleep 300

  # configure node role and node label
  sudo kubectl label node $HOSTNAME kubernetes.io/role=agent node-role.kubernetes.io/agent=

  # create initial.lock
  echo "create initial.lock"
  if [[ -f ~/.msmtprc ]] && [[ -f ~/mail.sh ]] && [[ ! -z "$MAIL_RECIPIENT" ]]
  then
    ~/mail.sh $MAIL_RECIPIENT InitialSetup-$HOSTNAME-Successful
  fi
  touch ~/initial.lock
  sudo reboot now
fi
