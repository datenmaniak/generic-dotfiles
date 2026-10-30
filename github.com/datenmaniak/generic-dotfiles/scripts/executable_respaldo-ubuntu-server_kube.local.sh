#!/usr/bin/bash

HOST="192.168.1.201"


echo "Respaldo del directorio /home/wp ..." 
sudo rsync wp@$HOST:~/ -aHAX --progress --delete \
  --exclude={'.cache/','.cargo/','.gnupg/','.icons/','.mozilla/','.pki/','.thunderbird/','.var/'} \
  --exclude='.local/share/containers/' \
  --exclude='.local/share/Trash/' \
 $HOME/respaldo-ubuntu-server-kube.local/slash_wp/


echo "Respaldo del directorio /root..."
sudo rsync wp@$HOST:/root -aHAX --progress --delete \
  --exclude={'.cache/','.cargo/','.config/','.gnupg/','.icons/','.mozilla/','.pki/','.thunderbird/','.var/'} \
  --exclude='.local/share/containers/' \
  --exclude='.local/share/Trash/' \
 $HOME/respaldo-ubuntu-server-kube.local/slash_root/


