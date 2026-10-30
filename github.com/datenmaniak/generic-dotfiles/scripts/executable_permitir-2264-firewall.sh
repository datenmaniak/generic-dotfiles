
sudo firewall-cmd --permanent --remove-port=2264/tcp
sudo firewall-cmd --permanent --zone=FedoraWorkstation --remove-port=1025-65535/tcp
sudo firewall-cmd --permanent --zone=FedoraWorkstation --remove-port=1025-65535/udp
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-port=2264/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --zone=FedoraWorkstation --list-all

