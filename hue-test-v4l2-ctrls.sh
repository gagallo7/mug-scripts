#!/bin/bash

for c in saturation brightness hue contrast; do
  for i in $(seq 0 5 255) 128; do
    v4l2-ctl -d /dev/v4l-subdev1 -c ${c}=${i};
    echo $c $i;
    sleep .2;
  done
done
