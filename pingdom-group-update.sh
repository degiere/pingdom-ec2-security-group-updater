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
old_ips=/tmp/pingdom-old-ips.txt
old_ports=/tmp/pingdom-old-ports.txt
ips=/tmp/pingdom-ips.txt

echo "Fetching old IPs in security group..."
aws ec2 describe-security-groups --group-id $group --query 'SecurityGroups[*].{Inbound:IpPermissions}' | grep FromPort | cut -d: -f2 | rev | cut -c 3- | rev > $old_ports
aws ec2 describe-security-groups --group-id $group --query 'SecurityGroups[*].{Inbound:IpPermissions}' | grep CidrIp | cut -d: -f2 | cut -c 3- | rev | cut -c 2- | rev > $old_ips

old_ip_count=`cat $old_ips | wc -l`

for i in `seq 1 $old_ip_count`;
do
	old_port=`sed "${i}q;d" $old_ports`
	old_ip=`sed "${i}q;d" $old_ips`
	aws ec2 revoke-security-group-ingress --group-id $group --cidr $old_ip --port $old_port --protocol tcp
done

echo "Fetching new pingdom probe ips..."
curl https://my.pingdom.com/probes/feed > $out

echo "Parsing IPs..."
grep pingdom:ip /tmp/pingdom.xml | sed -n 's:.*<pingdom\:ip>\(.*\)</pingdom\:ip>.*:\1:p' > $ips
lines=`cat $ips`

# for each ip, call the ec2 cli to add ips to a predefined pingdom only security group
# see: http://docs.amazonwebservices.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-AuthorizeSecurityGroupIngress.html
echo "Adding IPs to security group: $group"
for ip in $lines ; do
	aws ec2 authorize-security-group-ingress --group-id $group --cidr $ip/32 --port $port --protocol tcp
done

