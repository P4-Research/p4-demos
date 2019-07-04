This demo shows a simple rate limiter written in P4.

## How does it work? ##
This rate limiter limits the number of packets per second. Responsible for that are two variables
`BUCKET_SIZE` and `WINDOW_SIZE` placed in rate-limiter.p4 file. For instance now `BUCKET_SIZE` has value of 10 and `WINDOW_SIZE` has value of 100.
It means that 10 packets are passed in 100 ms window. It also means 100 packets per second.

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

## Example ##
Let's first run this example without rate limiting. 
Set up a `BUCKET_SIZE` with enormous value equal to 1000000.
Then test your max bandwidth.  
```
root@b8bc1e3eb949:/scripts# iperf -c 10.0.1.10 -b 100M -l 1470
WARNING: option -b implies udp testing
------------------------------------------------------------
Client connecting to 10.0.1.10, UDP port 5001
Sending 1470 byte datagrams
UDP buffer size:  208 KByte (default)
------------------------------------------------------------
[  5] local 10.0.0.10 port 33043 connected with 10.0.1.10 port 5001
[ ID] Interval       Transfer     Bandwidth
[  5]  0.0-10.0 sec   120 MBytes   100 Mbits/sec
[  5] Sent 85262 datagrams
[  5] Server Report:
[  5]  0.0-10.9 sec  14.9 MBytes  11.4 Mbits/sec   0.435 ms 74614/85260 (88%)
[  5]  0.0-10.9 sec  1 datagrams received out-of-order
```

Now let's set up `BUCKET_SIZE` to 10 and `WINDOW_SIZE` to 100. Then run iperf test again.  
```
root@f2da5b560e86:/scripts# iperf -c 10.0.1.10 -b 100M -l 1470
WARNING: option -b implies udp testing
------------------------------------------------------------
Client connecting to 10.0.1.10, UDP port 5001
Sending 1470 byte datagrams
UDP buffer size:  208 KByte (default)
------------------------------------------------------------
[  5] local 10.0.0.10 port 44216 connected with 10.0.1.10 port 5001
[ ID] Interval       Transfer     Bandwidth
[  5]  0.0-10.0 sec   119 MBytes  99.8 Mbits/sec
[  5] Sent 84875 datagrams
[  5] Server Report:
[  5]  0.0-10.5 sec  1.40 MBytes  1.12 Mbits/sec   2.636 ms 83866/84866 (99%)
```

As you can see a rate decreased to 1.12 Mbit/s.  
Let's compare it with theory. Our rate limiter should pass 100 packets per second. Packet has 1470 bytes.
So the available bandwidth should be (aproximately) `100 * 1470 * 8 = 1.176 Mbit/s`. 