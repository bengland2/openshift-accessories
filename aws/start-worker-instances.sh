#!/bin/bash -x
tag=$1
region=$2
aws ec2 start-instances --region $region --instance-ids `./get-worker-instance-ids.sh $tag $region`
