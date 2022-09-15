# sip-brute-force-attack-protection
Solution to help you be protected from distributed sip brute force attacks

Fail2ban is a great tool helping you be protected from normal brute force attacks, when an attacker just brute forces your sip accounts from one 'evil' ip address, which, depending on your fail2ban settings, gets blocked really quickly. 

I'm looking after an environment of more than hundred FPBXes, lately I noticed that with password brute force attacks the IP of attacker NEVER repeats, meaning every new attempt to crack your password comes from new IP address. With additional analysis I figured out that botnet may have around 1500 different IP addresses at this point of time and basically this beast attacks your SIP server every time from new IP. Fail2ban just can't block it. 

I managed to find a logical solution to block this from happening. Apart from locally blocking attackers on individual FPBXes, I've added central automated solution, which, if it sees more than 10 repeats of same blocked IP on all the FPBXes - it blockes it on the firewall on the datacentre edge.

Feedback, thoughts, improvements - welcome. 