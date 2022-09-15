#!/bin/bash
# Unified distributed brute force attack blocker (works on Elastix and FreePBX)
# Just add it to the cron, I run it every min. (You'd need a daily log rotation for your asterisk full log)
# version 0.99
# by Evgenii Buchnev
# 1. find configured extensions in FreePBX (if Ext is not configured in asterisk and we see a wrong password atempt in logs -> 99% it's a brute force attack)
# 2. find all wrong password attempts, filter out all for known(configured in the system) ext from step 1
# 3. filter out IPs from Allow list
# 4. block through iptables and email if list is not empty

# block_type may be "DROP" or "REJECT --reject-with icmp-port-unreachable", examples:
# block_type="REJECT --reject-with icmp-port-unreachable"
# block_type="DROP" #This seems working slightly better
block_type="DROP"
iptables_path="/sbin/iptables"

#For ELASTIX based servers we need additional config for MySQL
elastix_cfg="/etc/elastix.conf"
add_mysql_parametr=""
if [ -f "$elastix_cfg" ]; then
    touch /root/mysqlaccess.cfg && chmod 600 /root/mysqlaccess.cfg && echo '[client]' > /root/mysqlaccess.cfg && echo 'user=root' >> /root/mysqlaccess.cfg && echo "password=$(grep mysqlrootpwd /etc/elastix.conf | cut -d= -f2 | tr -d '\n')" >> /root/mysqlaccess.cfg 
    add_mysql_parametr="--defaults-extra-file=/root/mysqlaccess.cfg"
fi

# Allowed IPs can be set up in /root/distributed_BFA_Allowed_IPs.cfg(list, one per line) or any host properly listed in:  /etc/hosts
allowed_IPs=$(grep -hsoE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" /etc/hosts /root/distributed_BFA_Allowed_IPs.cfg)
if [ -z "${allowed_IPs}" ]; then
    allowed_IPs="none"
fi

#Configured Extensions in FPBX
fpbx_ext_list=$(mysql $add_mysql_parametr -sssD asterisk -e 'select distinct id from sip where id not like "tr%";' | sort | uniq | awk '{print "sip:"$1"@"}' )

#Get already banned IPs from IPTABLES
already_banned=$($iptables_path  -L INPUT -n | egrep "^DROP|^REJECT" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | grep -v '0.0.0.0' | sort | uniq | awk '{print $1}' )
if [ -z "${already_banned}" ]; then
    already_banned="none"
fi

#Getting Wrong PW attempts, filtering out 'Configured Extensions in FPBX' and filtering out what has been already blocked, filtering out IPs from Allow list
fresh_ban=$(grep 'failed for'  /var/log/asterisk/full | grep 'Wrong password' | grep -wv -F "$fpbx_ext_list" | grep -oP "failed for.+" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort | uniq | grep -wv -F "$already_banned" | grep -wv -F "$allowed_IPs" | tee -a /var/log/badboys.log )  

if [[ $(echo -e "$fresh_ban") ]]; then
    echo -e "$fresh_ban" | xargs -r -I '{}' $iptables_path -I INPUT -s '{}' -m comment --comment "DBFAB" -j $block_type 2>&1
    echo -e "BadBoys:\n$fresh_ban" 
    echo -e "BadBoys:\n$fresh_ban" | mail  -s "$(hostname -i)_$(hostname -f)_BANNED_DISTRIBUTED_BFA" your@email.ad
else
    echo "No new BadBoys"
fi
