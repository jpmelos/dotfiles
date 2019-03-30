#!/usr/bin/env python3

from configparser import SafeConfigParser
import os
import shlex
import subprocess
import sys
import tempfile


def run(command, check_errors=True, *args, **kwargs):
    completed_process = subprocess.run(shlex.split(command), universal_newlines=True, *args, **kwargs)
    if check_errors:
        completed_process.check_returncode()
    return completed_process


mode = sys.argv[1]
vpn = sys.argv[2]

vpn_file = os.sep + os.path.join('etc', 'wireguard', '{}.conf'.format(vpn))
vpn_conf = SafeConfigParser()
vpn_conf.read(vpn_file)

ip_address, port = vpn_conf['Peer']['Endpoint'].split(':')

if mode == 'up':
    run('sudo iptables -D INPUT '
        '-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT')
    run('sudo iptables -A INPUT '
        '-i {} '
        '-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'.format(vpn))
    run('sudo iptables -A INPUT '
        '-p udp -s {} --sport {} '
        '-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'.format(ip_address, port))

    run('sudo iptables -D OUTPUT '
        '-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT')
    run('sudo iptables -A OUTPUT '
        '-o {} '
        '-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT'.format(vpn))
    run('sudo iptables -A OUTPUT '
        '-p udp -d {} --dport {} '
        '-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT'.format(ip_address, port))

elif mode == 'down':
    run('sudo iptables -D INPUT '
        '-i {} '
        '-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'.format(vpn))
    run('sudo iptables -D INPUT '
        '-p udp -s {} --sport {} '
        '-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'.format(ip_address, port))
    run('sudo iptables -A INPUT '
        '-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT')

    run('sudo iptables -D OUTPUT '
        '-o {} '
        '-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT'.format(vpn))
    run('sudo iptables -D OUTPUT '
        '-p udp -d {} --dport {} '
        '-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT'.format(ip_address, port))
    run('sudo iptables -A OUTPUT '
        '-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT')
