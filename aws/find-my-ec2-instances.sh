#!/bin/bash -x
# return non-zero process exit status if nothing found, 
# so ansible will abort
tag=$1
region=$2
if [ -z "$tag" ] ; then
  echo "usage: find-my-ec2-instances.sh tag-prefix [ region ]"
  exit 1
fi
if [ -n "$region" ] ; then
    region="--region $region"
fi
aws ec2 describe-instances $region --filters Name=tag:Name,Values="${tag}*" | \
	tr '|' ' ' | \
    awk '/InstanceId/{print $NF}' | \
    tee /tmp/ec2-hosts.list
if [ `wc -l < /tmp/ec2-hosts.list` = 0 ] ; then 
	exit 1
fi
