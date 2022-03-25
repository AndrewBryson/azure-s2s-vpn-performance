#!/bin/bash

docker run -it --rm --network host networkstatic/iperf3 -c $*