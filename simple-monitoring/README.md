This demo shows how to use counters in P4.

## How to run? ##
Run app via `sudo p4app run simple-monitoring/simple_monitoring.p4app`

## Example ##
This demo implements 4 counters. At the startup one host pings the second for 10 seconds.
At the end you can see switch counters values.
```.
...
ping h2 -w 10
ping 10.0.2.101 -w 10
h1 ping 10.0.2.101 -w 10
h1 (None, '')
Counter ipv4_lpm_counter(0): packets=10, bytes=980
Counter ipv4_lpm_counter(1): packets=10, bytes=980
Counter set_nhop_counter(0): packets=20, bytes=1960
Counter drop_counter(0): packets=0, bytes=0
Counter set_dmac_counter(0): packets=20, bytes=1960
...
```