#!/bin/bash

docker run -it --rm -p 11111:11111 --network host --hostname server sagoel/sockperf:1.0 /app/sockperf $*