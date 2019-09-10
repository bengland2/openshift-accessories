#!/bin/bash -x
region=${REGION:-"us-east-2"}
vsize=${VOLUME_SIZE:-50}
vtype=${VOLUME_TYPE:-gp2}
osds_per_host=1
device_letters=( c d e f g h )
NOTOK=1

if [ osds_per_host -gt ${#device_letters[*]} ] ; then
    echo "need to expand device_letters array"
    exit $NOTOK
fi
echo creating RHOCS cluster in region $region
echo volume size $vsize GB
echo volume type $vtype 
echo device name /dev/sd$device_letter = /dev/xvd$device_letter

timestamp=`date +%Y-%m-%d-%H-%M`
mkdir $timestamp
sed "s/TIMESTAMP/$timestamp/" < install-config-template.yaml | \
 sed "s/REGION/$region/" > $timestamp/install-config.yaml
echo "if you want to edit config:"
echo "control-Z, edit $timestamp/install-config.yaml , fg, hit Enter key"
read line
cp $timestamp/install-config.yaml $timestamp/install-config.saved.yaml
cmd="./openshift-install create cluster --dir=$timestamp" || exit $NOTOK
echo "running this command in 5 seconds: "
echo "$cmd"
sleep 5
$cmd || exit $NOTOK
echo logs are in directory $timestamp ...
export KUBECONFIG=`pwd`/$timestamp/auth/kubeconfig
for k in `seq 1 $osds_per_host` ; do
  (( index = $k - 1 ))
  device_letter=${device_letters[${k}]}
  cmd="./attach-vols.sh bene-$timestamp h $vsize $vtype $region"
  echo "$cmd"
  $cmd || exit $NOTOK
done
cd rook/cluster/examples/kubernetes/ceph
./create-ceph-cluster.sh


