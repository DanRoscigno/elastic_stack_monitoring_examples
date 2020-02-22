#!/bin/sh

echo "Do you wish to remove any existing containers named elasticsearch, kibana, metricbeat, and filebeat?"
select ynq in "Yes" "No" "Quit"; do
    case $ynq in
        Yes ) docker rm -f elasticsearch  kibana  metricbeat  filebeat; break;;
        No ) echo "Continuing ..."; break;;
        Quit ) exit;;
    esac
done
