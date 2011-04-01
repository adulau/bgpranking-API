#!/bin/sh
sudo socat TCP6-LISTEN:43,fork,tcpwrap=script,ipv6only=0  EXEC:/home/adulau/git/bgpranking-api/bin/getranking.pl,su-d=adulau,pty,stderr

