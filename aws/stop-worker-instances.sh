#!/bin/bash -x
tag=$1
region=$2
aws ec2 stop-instances --region $region --no-hibernate --instance-ids `./get-worker-instance-ids.sh $tag $region`
