#!/bin/bash
#
# parameter 1 : name tag prefix for instances (separating my instances from everyone elses)
# remaining parameters: internal DNS names for each AWS instance of interest
# if no DNS names are specified, it will default to getting all the 
# OpenShift worker hosts' DNS names and pass them in
tag=$1
region=$2
shift
shift
if [ -n "$*" ] ; then
    dnsnames="$*"
else
    dnsnames=`./get-worker-dns-names.sh $tag`
fi
for h in $dnsnames ; do 
  #echo -n "$h "
  aws ec2 describe-instances --region $region --filters \
    Name=tag:Name,Values=${tag}* Name=network-interface.private-dns-name,Values=${h} \
  | tr '|' ' ' \
  | awk '/InstanceId/{print $2}'
done
