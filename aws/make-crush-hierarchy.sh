#!/bin/bash
# make-crush-hierarchy.sh puts all hosts within their availability zones
# enabling crush rules that place data across AZs
# assumes that the default crush map is in place
# i.e. default -> host -> osd

if [ -z "$KUBECONFIG" ] ; then exit 1 ; fi
toolbox_pod=$( oc -n rook-ceph get pods | grep tool | awk '{ print $1 }' )
toolbox="oc -n rook-ceph rsh $toolbox_pod"
hostnames=$(echo ceph osd tree | $toolbox | awk '/host/{print $4}')

# determine availability zone for each host in crush map

for h in $hostnames ; do
   echo -n "$h,"
   aws ec2 describe-instances --filters \
       "Name=network-interface.private-dns-name,Values=${h}*" \
   | tr '|' ' ' \
   | awk '/AvailabilityZone/{print $2}'
done | tee /tmp/table

# generate commands moving host to AZ bucket

for t in `cat /tmp/table` ; do
  h=`echo $t | cut -d, -f1` 
  az=`echo $t | cut -d, -f2` 
  region=`echo $az | sed 's/[a-z]$//'`
  cmd="ceph osd crush move $h datacenter=$az" 
  echo $cmd 
done | tee /tmp/host_moves.sh

# generate set of AZs 

for t in `cat /tmp/table` ; do
  h=`echo $t | cut -d, -f1` 
  az=`echo $t | cut -d, -f2` 
  echo $az
done | sort -u > /tmp/az.list

# generate crush bucket for each AZ

for az in `cat /tmp/az.list` ; do 
 echo ceph osd crush add-bucket $az datacenter
 echo ceph osd crush move $az root=default
done | tee /tmp/make_az_buckets.sh

# place hosts within each AZ

cat /tmp/host_moves.sh >> /tmp/make_az_buckets.sh
echo "/tmp/make_az_buckets.sh is a shell script to create your crush buckets"
