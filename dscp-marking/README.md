This demo shows a simple dscp maker written in P4.

## How to run? ##
Run app via `sudo p4app run dscp-marking/dscp_marking.p4app`

## Example ##
In this demo there is implemented an action _dscp_mark_. When p4app runs then a appropriate table entry is inserted.
(see `dscp_marking.config` file). Every IPv4 packet is marked by **15**.

First step is to run a tcpdump server.  
`tcpdump -i h2-eth0 -vv`

Then ping host h2. As the result you can see marked packets in tcpdump (**tos 0xf**).

```.
...
08:38:57.800562 IP (tos 0xf,CE, ttl 63, id 45249, offset 0, flags [DF], proto ICMP (1), length 84)
...
```