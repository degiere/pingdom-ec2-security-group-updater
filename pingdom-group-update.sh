#!/bin/sh

usage() {
	echo "Usage: $0 group port"
	exit 1
}

# print usage if cli args not provided
[[ $# -eq 0 ]] && usage

# set group and port or default port
group=$1
port=$2
: ${port:="8080"}
out=/tmp/pingdom.xml
ips=/tmp/pingdom-ips.txt

echo "Fetching new pingdom probe ips..."
curl https://my.pingdom.com/probes/feed > $out

echo "Parsing IPs..."
grep pingdom:ip /tmp/pingdom.xml | sed -n 's:.*<pingdom\:ip>\(.*\)</pingdom\:ip>.*:\1:p' > $ips
lines=`cat $ips`

# TODO: handle duplicates or delete all first

# for each ip, call the ec2 cli to add ips to a predefined pingdom only security group
# see: http://docs.amazonwebservices.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-AuthorizeSecurityGroupIngress.html
echo "Adding IPs to security group: $group"
for ip in $lines ; do
	aws ec2 authorize-security-group-ingress --group-id $group --cidr $ip/32 --port $port --protocol tcp
done

