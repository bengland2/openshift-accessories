This directory contains scripts useful for deploying Ceph on an AWS cluster.  Some of this may become obsolete if
rook.io takes over these functions, but use as you see fit:

* attach-vols.sh -- attaches AWS EBS volume at specified device letter to a set of hosts
* create-aws-rhocs.sh -- creates an openshift 4 cluster, attaches volumes and then runs rook to install ceph cluster
* create-ec2-vol.sh -- create a single EBS volume and attach it to an instance (VM)
* delete-ceph-volumes.sh - detach EBS volume from its instance and delete it
* find-my-ec2-instances.sh -- find all instances in a region with specified tag:Name prefix
* get-worker-dns-names.sh -- ask openshift what DNS names of worker instances are
* get-worker-instance-ids.sh -- get AWS instance IDs of all OpenShift workers
* make-crush-hierarchy.sh -- move host into a CRUSH bucket for its AZ
* start-worker-instances.sh -- boot the openshift worker node instances
* stop-worker-instances.sh -- shutdown the openshift worker instances (so we can detach vols)
