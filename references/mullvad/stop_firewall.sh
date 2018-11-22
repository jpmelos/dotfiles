sudo cp ~/devel/dotfiles/references/resolv.conf /etc/resolv.conf

sudo iptables -D INPUT -i tun0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -D INPUT -i wlp2s0 -s 192.168.0.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -D INPUT -p udp -m udp -i wlp2s0 -s 177.67.80.186 --sport 1302 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

sudo iptables -D OUTPUT -o tun0 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -D OUTPUT -o wlp2s0 -d 192.168.0.0/24 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -D OUTPUT -p udp -m udp -o wlp2s0 -d 177.67.80.186 --dport 1302 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
