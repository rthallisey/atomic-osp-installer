#!/bin/bash -x

for i in `ls -1 Dockerfile.*`; do
  extention=`echo $i | cut -d'.' -f2`
  docker build -f $i -t imain/atomic-install-$extention:latest .
done
