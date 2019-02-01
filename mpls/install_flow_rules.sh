#!/usr/bin/env bash

# Install flow rules for switch S1
simple_switch_CLI --thrift-port 9090 < s1-commands

# Install flow rules for switch S1
simple_switch_CLI --thrift-port 9091 < s2-commands

# Install flow rules for switch S1
simple_switch_CLI --thrift-port 9092 < s3-commands