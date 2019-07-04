# Introduction

This repository contains P4 program implementing the [stateful firewall](https://en.wikipedia.org/wiki/Stateful_firewall).

Every TCP packet is analyzed to track the state of the TCP connection. If the traffic belongs to known connection it 
is passed. Otherwise, it is dropped.

We have implemented stateful firewall using P4 register arrays.

# How to use?

We use [p4app](https://github.com/p4lang/p4app) for testing P4 programs. 

`sudo p4app run stateful_firewall.p4app`

```
*** Starting CLI:
mininet> h2 python -m SimpleHTTPServer 80 &
mininet> h1 wget h2
--2019-07-04 11:52:01--  http://10.0.1.10/
Connecting to 10.0.1.10:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 831 [text/html]
Saving to: 'index.html'

index.html          100%[===================>]     831  --.-KB/s    in 0s      

2019-07-04 11:52:02 (168 MB/s) - 'index.html' saved [831/831]
```

View the switch log in order to analyze how the P4 application tracks the TCP connection:

`docker exec -t -i <container-id> tail -f /var/log/stateful_firewall.p4.log`



