#!/bin/bash

docker run -it --rm --network host --hostname client sagoel/sockperf:1.0 /app/sockperf $*