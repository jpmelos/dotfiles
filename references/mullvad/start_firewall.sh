sudo cp resolv.conf /etc/resolv.conf

sudo iptables -D INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -D OUTPUT -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

sudo iptables -A INPUT -i tun0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p udp -m udp -i wlp2s0 -s 185.65.135.143 --sport 1302 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

sudo iptables -A OUTPUT -o tun0 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p udp -m udp -o wlp2s0 -d 185.65.135.143 --dport 1302 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
