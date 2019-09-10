#!/bin/bash
tag=$1
letter=$2
size=$3
voltype=$4
region=$5
if [ -z "$5" ] ; then 
    echo "usage: attach-vols.sh cluster-tag letter size voltype region"
    exit 1
fi 

workers=$(./get-worker-instance-ids.sh $tag $region)
echo $workers

for worker in $workers ; do 
  cmd="./create-ec2-vol.sh --size $size --region $region --device-letter $letter --voltype $voltype --ec2-instance $worker --tag $tag"
  echo $cmd
  $cmd 2>&1
done
