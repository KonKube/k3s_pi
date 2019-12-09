#!/bin/bash

set -e

HOSTNAME=$1
MAIL_SENDER=$2
NODE_TOKEN=$3

if [[ ! -f ~/initial.lock ]]
then

  # initialize locales
  sudo /usr/sbin/locale-gen en_GB.UTF-8

  # initial update and upgrade on first boot
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

  # install k3s
  curl -sfL https://get.k3s.io -o install.sh
  chmod 755 install.sh
  ./install.sh agent --server https://k3s-master:6443 --kubelet-arg="address=0.0.0.0" --token $NODE_TOKEN

  # sleep for startup of k3s
  sleep 300

  # configure master node role and node label
  sudo kubectl label node $HOSTNAME kubernetes.io/role=agent node-role.kubernetes.io/agent=

  if [[ -f ~/ssmtp.conf ]] && [[ -f ~/mail.sh ]]
  then
    # install email resources
    sudo apt-get -y install \
      ssmtp \
      mailutils

    sudo cp  ~/ssmtp.conf /etc/ssmtp/ssmtp.conf
    echo "pi:$MAIL_SENDER:smtp.gmail.com:587" | sudo tee -a /etc/ssmtp/revaliases
  fi

  # create initial.lock
  touch ~/initial.lock
  sudo reboot now
fi
