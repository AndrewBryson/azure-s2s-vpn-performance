# Purpose
Test Azure site-to-site (S2S) VPN latency.  This test uses 2 Azure regions (UK West, UK South) to simulate results if using VPN on top of an Azure ExpressRoute, i.e. {ExpressRoute POP} <--> {Azure Region}.

Scenarios tested are:
1. Cross-region latency using site-to-site VPN.  VPN Gateway SKU is `VpnGw2AZ` running active/passive.
2. Cross-region latency using public IPs (PIP) only, no VPN.
3. Site-to-site VPN latency with concurrent load test.

# Configuration

## Approach
Using Docker-based tools, the tests mimic the guidance found here: https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-validate-throughput-to-vnet

## Tools
- Latency test with sockperf: https://hub.docker.com/r/sagoel/sockperf.  Uses [sockperf under-load](https://www.systutorials.com/docs/linux/man/3-sockperf/#lbAH) mode to measure latency with high load applied.
- Throughput test with iperf: https://hub.docker.com/r/networkstatic/iperf3.
- Ubuntu 20.04, running on D2v5 VMs, with Accelerated Networking enabled.

Convenience scripts for running the above tools with Docker can be found in the repository.

# Results

## Scenario 1 - site-to-site VPN
![S2S](/images/s2s.png)

### Summary
- Results taken over 3 executions, each 101 seconds in duration.
- 10 minute sleep between executions.
- Raw command output [here](/results/tools-output/sockperf-results-private.txt).

| Run | Sent Messages | Round trip time | 50th % | 75th % | 90th % |  99th % | 99.9th %|
|--------------|--------------|-----------|-----------|-----------|-----------|-----------|-----------|
| 1 | 1005301 | 6717us | 6192us | 6490us | 7283us | 15326us | 50342us |
| 2 | 1005001 | 6591us | 6180us | 6449us | 7160us | 13912us | 22695us |
| 2 | 1010000 | 6916us | 6155us | 6277us | 7236us | 15492us | 54320us |

Observation:
- Latency at higher percentiles increases significantly compared to lower percentiles.
- Most noticeable in the 90th to 99th percentile, e.g. a doubling of latency.
- For latency sensitive workloads this would affect ~10% of traffic.
- The VPN Gateways (1 at each end) must be playing a part here.

### Egress data transfer
![S2S data transfer](/results/images/sockperf-results-private.png)


## Scenario 2 - PIP to PIP (no VPN)
![PIP-no-VPN](/images/pip.png)

### Summary
- Results taken over 3 executions of 101 seconds.
- 10 minute sleep between executions.
- Raw command output [here](/results/tools-output/sockperf-results-public.txt)

| Run | Sent Messages | Round trip time | 50th % | 75th % | 90th % |  99th % | 99.9th %|
|--------------|--------------|-----------|-----------|-----------|-----------|-----------|-----------|
| 1 | 1005301 | 2503us | 2456us | 2495us | 2537us | 3517us | 3946us |
| 2 | 1005301 | 5873us | 5828us | 5853us | 5910us | 6968us | 7268us |
| 2 | 1005101 | 5329us | 5311us | 5323us | 5378us | 5715us | 6452us |

Observation:
- Latency across percentiles with a run are very similar.
- There is no jump in latency at higher percentiles, e.g. 75th to 90th percentile.

### Egress data transfer
![S2S data transfer](/results/images/sockperf-results-public.png)


## Scenario 3 - site-to-site VPN with concurrent load test
- Using `iperf` to apply a fixed 1 Gbps load.
- Using `sockperf` to measure latency as above.
- Solution as per scenario 1 diagram above.

### Latency Summary
- Result taken from a single execution of 101 seconds.
- Test run in [sockperf ping-pong](https://www.systutorials.com/docs/linux/man/3-sockperf/#lbAH) mode, leaving load testing to `iperf`.
- This means the total Sent Messages compared to the above scenarios is lower.
- Raw command output [here](/results/tools-output/concurrent-results.txt).

Sent Messages | Round trip time | 50th % | 75th % | 90th % |  99th % | 99.9th %|
|--------------|-----------|-----------|-----------|-----------|-----------|-----------|
| 14674 | 6885us | 6356us | 6667us | 8009us | 15453us | 46318us |

Observations:
- Throughput as measured `sockperf` Sent Messages is much lower with the concurrent `iperf` test.
- Latency remains pretty good until 99th+ percentiles.

### iperf output (load test throughput)
- Single iperf thread.
- Bitrate cap at 1Gbps (imposed by the `iperf` client).
```
... snip ...
[  5] 197.00-198.00 sec   119 MBytes  1.00 Gbits/sec    0   1.16 MBytes
[  5] 198.00-199.00 sec   119 MBytes  1.00 Gbits/sec    0   1.17 MBytes
[  5] 199.00-200.00 sec   119 MBytes   999 Mbits/sec    0   1.18 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-200.00 sec  23.3 GBytes  1000 Mbits/sec  3119             sender
[  5]   0.00-200.01 sec  23.3 GBytes  1000 Mbits/sec                  receiver
```

- This shows 1.00 Gbps.
- Transferring 23 GB over the 200 second test duration.

## Bonus: Throughput of an active/active S2S VPN

### Outline
An Azure VPN Gateway provisions and manages 2 VMs behind the scenes.  In the testing above the VPN was configured in an active/passive mode meaning only 1 of those VMs were being utilised.  Active/active can help achieve higher aggregate throughput by using both VMs.  In this scenario, latency was not measured, only throughput.

### Configuration
- Same as above: UK West and UK South; same client & server VMs.
- S2S VPN is not connecting Virtual Networks, it's connecting Microsoft-routed public IP addresses with IPSec.
- VPN Gateway SKU: [VpnGw4](https://azure.microsoft.com/en-gb/pricing/details/vpn-gateway/).
- References:
    - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-highlyavailable#active-active-vpn-gateways
    - https://docs.microsoft.com/en-us/azure/vpn-gateway/active-active-portal

### Results
I consistently achieved >8Gbps using iPerf configuration of 64 threads (`iperf client --parallel 64`).  Increasing thread count (more concurrency) is important to achieve a higher bandwidth utilisation.

Test run # | Thread count | Duration | Achieved aggregate throughput |
| ---- | ---- | ---- | ---- |
1 | 16 | 600 seconds | 6.17 Gbits/sec |
2 | 64 | 60 seconds | 9.36 Gbits/sec |
3 | 64 | 60 seconds |  8.28 Gbits/sec |

I executed a bunch of other tests but the above is a fair summary.

A higher throughput can be achieved by using both VPN Gateways because the Virtual Network has 2 routes to the remote network; see below that UK West has 2 routes to UK South (`10.1.0.0/16`) through the 2 next hop IPs of the VPN Gateway VMs (`10.2.1.4`, `10.2.1.5`).
![S2S active active routes](/results/images/s2s-active-active-routes.png)

We can see the bandwidth utilisation of both Connections (to primary and secondary public IPs of the remote VPN Gateway); here metrics showing ~2.3 Gb/s and ~2.5 Gb/s.
![S2S active active connection bandwidth metrics](/results/images/s2s-active-active-connection-bandwidth-metrics.png)