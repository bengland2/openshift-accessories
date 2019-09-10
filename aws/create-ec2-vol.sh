#!/bin/bash
# CLI parameters are:
#  1 - size in GiB
#  2 - volume type (hdd or ssd)
#  3 - device letter (do not use "a", that is the operating system disk
#  4 - ec2 instance ID - used to attach volume to EC2 instance
#  5 - tag - prefix used to provide a user-friendly name to the volume
#
# if either the instance or the volume is not ready when the attach is tried,
# this script will wait until they are both ready

region="us-east-1"
iorate=500                  # IOPS for SSD vol
voltype='sc1'               # worst-performing, cheapest volume
size_GiB=500                # size for vol (500 min size for HDD)
deviceletter=f             # default for a single device per instance
zoneletter=''

# should not have to edit below this line

NOTOK=1 # failure process exit status
OK=0 # successful process exit status

usage() {
        echo "ERROR: $1"
        echo 'usage: create-ec2-vol.sh '
        echo "[ --size size-GiB (default $size_GiB)]"
        echo "[ --voltype AWS-volume-type (default $voltype)]"
        echo "[--region geographic-region-name (default $region)]"
        echo '--device-letter a-z'
        echo '--zone-letter a-z'
        echo '--ec2-instance instance-id'
        echo '--tag name-prefix'
        exit $NOTOK
}

# parse command line arguments

while [ -n "$1" ] ; do
        if [ -z "$2" ] ; then
                usage "$1: missing parameter value"
        fi
        case $1 in
                --size)
                        size_GiB=$2
                        ;;
                --voltype)
                        voltype=$2
                        ;;
                --device-letter)
                        deviceletter="$2"
                        ;;
                --ec2-instance)
                        ec2_instance="$2"
                        ;;
                --region)
                        region="$2"
                        ;;
                --tag)
                        tag="$2"
                        ;;
                --iops)
                        iorate=$2
                        ;;
                --zone-letter)
                        zone_letter=$2
                        ;;
                *)
                        usage "invalid parameter name: $1"
                        ;;
        esac
        shift
        shift
done

if [ -z "$ec2_instance" ] ; then 
    usage "must supply --ec2-instance" 
fi
if [ -z "$zone_letter" ] ; then 
    # look up availability zone for this instance
    zone=$(aws ec2 describe-instances --region $region --instance-ids="$ec2_instance" | \
            tr '|' ' ' | \
            awk '/AvailabilityZone/{print $NF}' || exit 1)
else
    zone=${region}${zone_letter}
fi

if [ -z "$tag" ] ; then 
        vol_tag="${USER}_${ec2_instance}_$deviceletter"
else
        vol_tag="${tag}_${ec2_instance}_$deviceletter"
fi
if [ "$voltype" = "io1" ] ; then
        iops="--iops $iorate"
fi
echo "availability zone: $zone"
echo "drive name: /dev/xvd$deviceletter"
echo "EC2 instance: $ec2_instance"
echo "volume type: $voltype"
echo "size (GiB): $size_GiB"
echo "volume tag: $vol_tag"
echo "iops: $iops"

# save results here

errfn=/tmp/create-ec2-$$-err.log
outfn=/tmp/create-ec2-$$-out.log
rm -f $errfn $outfn

# if error occurs after volume is created, use this to clean it up
# we don't want orphaned volumes to rack up charges from AWS

cleanup() {
        echo "ERROR: $2"
        echo "deleting instance $1" | tee -a $errfn
        aws ec2 delete-volume --volume-id "$1" 2>&1 | tee -a $errfn
        exit $NOTOK
}

# create volume and remember its id

cmd="aws ec2 create-volume --region $region --availability-zone $zone --volume-type $voltype $iops --size $size_GiB --no-encrypted"
echo "$cmd"
$cmd 2>&1 | tee /tmp/create-volume.log
id=`awk '/VolumeId/{print $4}' /tmp/create-volume.log`
if [ $? != 0 -o -z "$id" ] ; then
        exit $NOTOK
fi

# tagging is very important so we can find the volume and clean it up later on

cmd2="aws ec2 create-tags --region $region --resources $id --tags Key=Name,Value=${vol_tag}"
echo "$cmd2"
$cmd2
if [ $? != 0 ] ; then 
        cleanup $id "ERROR: could not tag volume $id with tag $vol_tag"
fi

# attach the volume to the EC2 instance
# allow some parallelism but don't overstimulate ec2

while [ 1 ] ; do  # until volume is either attached or can't be attached
        cmd="aws ec2 attach-volume \
                --region $region \
                --volume-id $id \
                --instance-id $ec2_instance \
                --device /dev/sd$deviceletter "
        (echo "$cmd" ; eval "$cmd") 2>$errfn 1>$outfn
        if [ $? != $OK ] ; then
                if grep -q 'volume not ready' $errfn ; then
                        sleep 5
                elif grep -q "is not 'running'" $errfn ; then
                        sleep 5
                elif grep -q "is not 'available'" $errfn ; then
                        sleep 5
                elif grep -q "instance does not exist" $errfn ; then
                        cat $outfn $errfn
                        cleanup $id 'error attaching volume - no ec2 instance'
                else
                        cat $outfn $errfn
                        cleanup $id 'error attaching volume'
                fi
        else
                # this last one means EC2 should automatically
                # delete volumes when attached instance is terminated?
                aws ec2 modify-instance-attribute \
                        --region $region \
                        --instance-id $ec2_instance \
                        --block-device-mappings "[{\"DeviceName\":\"/dev/sd$deviceletter\", \"Ebs\":{\"DeleteOnTermination\":true}}]"
                break  # success, volume is attached
        fi
done
cat $outfn $errfn
echo $id
