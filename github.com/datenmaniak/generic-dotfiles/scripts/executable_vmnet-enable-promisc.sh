#!/bin/sh

sudo chgrp vmware /dev/vmnet0 /dev/vmnet8 /dev/vmnet1
sudo chmod g+rw /dev/vmnet0 /dev/vmnet8 /dev/vmnet1

sudo ls -l /dev/vmnet0 /dev/vmnet1 /dev/vmnet8
