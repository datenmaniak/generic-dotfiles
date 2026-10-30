sudo nmcli conn mod "eno1" -ipv4.address 10.242.160.200/24

sudo nmcli conn mod "eno1" -ipv4.routes "10.242.160.0/24 10.242.160.1" 






sudo nmcli conn up "eno1"
