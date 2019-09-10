#!/bin/bash
oc get nodes | awk '/worker/{ print $1 }'
