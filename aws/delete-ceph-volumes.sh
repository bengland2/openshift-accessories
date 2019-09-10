#!/bin/bash -x
tag=$1
device_letter=$2
region=$3
devicename="/dev/sd$device_letter"
jsonfn=/tmp/v$$
aws --output json ec2 describe-volumes \
  --region $region \
  --filters "Name=tag:Name,Values=${tag}*" > $jsonfn
vols=($(cat $jsonfn | jq '.Volumes[].Attachments[].VolumeId' | tr '"' ' '))
insts=($(cat $jsonfn | jq '.Volumes[].Attachments[].InstanceId' | tr '"' ' '))
devs=($(cat $jsonfn | jq '.Volumes[].Attachments[].Device' | tr '"' ' '))
count=${#devs[*]}
for c in `seq 1 $count` ; do 
  v=${vols[$c]}
  i=${insts[$c]}
  d=${devs[$c]}
  if [ -z $d ] ; then
    continue
  fi
  if [ "$d" = "$devicename" ] ; then
    aws ec2 detach-volume --region $region --device $d --instance-id $i --volume-id $v || continue
    while [ 1 ] ; do 
      sleep 1
      # this can fail because volume is not yet detached, keep trying
      aws ec2 delete-volume --region $region --volume-id $v && break
    done
  fi
done
