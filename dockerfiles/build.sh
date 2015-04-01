#!/bin/bash -x

rm pull.sh

for i in `ls -1 Dockerfile.*`; do
  extention=`echo $i | cut -d'.' -f2`
  docker build -f $i -t imain/atomic-centos-rdo-$extention:latest .
  docker push imain/atomic-centos-rdo-$extention:latest
  echo docker pull imain/atomic-centos-rdo-$extention:latest >> pull.sh
done
