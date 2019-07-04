This demo shows a simple rate limiter written in P4.
## How to run? ##
Run app via `sudo p4app run rate-limiter/rate_limiter.p4app`

## How to measure a bandwidth? ##
Run hosts terminals from mininet from docker  
`p4app exec m h1 bash`  
`p4app exec m h2 bash`  

Start i.e. a iperf UDP server(on h2)  
`iperf -s -u`  
Then on the h1 run iperf client  
`iperf -c 10.0.1.10 -b 10M -l 147`  
- `b` flag sets up UDP bandwidth
- `l` flag sets up length read/write buffer (in consequence this sets up datagram size)