# 1 liner - runs the `sockperf` client 3 times, each for 101 seconds, prints the date/time, then sleeps for 600 seconds.
for i in {0..2}; do ./sockperf-client-start-docker.sh ul -i $(dig +short south-private) --time 101 --full-rtt --tcp --msg-size 1400 && echo $(date) && sleep 600s; done