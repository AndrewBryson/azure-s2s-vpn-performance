#!/bin/bash

docker run -it --rm -p 5201:5201 --network host networkstatic/iperf3 -s