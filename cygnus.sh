#!/bin/bash

# Find out where we're running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get our IPv4
CYGNUS_IP4=$(ip route get 1 | awk '{print $NF;exit}')
# Get our IPv6
CYGNUS_IP6=$(ip addr show dev eth0 | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | awk ' { if ( length > x ) { x = length; y = $0 } }END{ print y }')
# Use the defaults from Pi-hole if they exist
if [[ -f /etc/pihole/setupVars.conf ]]; then
  CYGNUS_IP4=$(grep "IPV4" /etc/pihole/setupVars.conf | awk -F "=" '{print $2}'| awk -F "/" '{print $1}')
  CYGNUS_IP6=$(grep "IPV6" /etc/pihole/setupVars.conf | awk -F "=" '{print $2}')
fi


# USS Cygnus's sources of blocklists are very divers:
# Sources that supply just a list of hostnames, one per line:
CYGNUS_FLAT_LIST="${SCRIPT_DIR}/sources.flat.txt"
# Sources that supply their list formatted as a hosts file:
CYGNUS_127_LIST="${SCRIPT_DIR}/sources.127.txt"
# Sources that supply a list of URLs (we will block the entire domain)
CYGNUS_URL_LIST="${SCRIPT_DIR}/sources.url.txt"
# Sources that supply a list of IPs:
CYGNUS_IPs_LIST="${SCRIPT_DIR}/sources.ip.txt"

# Pi-hole keeps it's own hosts list. We will absorb this into ours
PIHOLE_GRAVITY_LIST="/etc/pihole/gravity.list"
# to be added: dnsmasq native methods

# USS Cygnus allows you're own blacklist and will add it if it exists.
CYGNUS_LOCALBLACK_LIST="${HOME}/.config/cygnus/black.list"
# USS Cygnus allows you're personal whitelist
CYGNUS_LOCALWHITE_LIST="${HOME}/.config/cygnus/white.list"
# USS Cygnus also comes with it's own whitelist
CYGNUS_WHITE_LIST="${SCRIPT_DIR}/white.list"

# Where to put the output
CYGNUS_OUTPUT=$(mktemp /tmp/cygnus.list.XXXXXX)

# A temporary file for storing the intermediate results
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)


echo "Fetching 'flat' and '127' lines..."
cat ${CYGNUS_FLAT_LIST} ${CYGNUS_127_LIST} | wget --timeout=20 -qnv -i - -O ${TMP_FILE}

echo "Filtering..."
${SCRIPT_DIR}/filter.py ${TMP_FILE}

echo "Adding 'URL' lines..."
wget --timeout=20 -qnv -i ${CYGNUS_URL_LIST} -O - | sed -e '/\s*#.*$/d' -e '/^\s*$/d' | cut -c8- | awk -F/ '{print $1}' >> ${TMP_FILE}

# The list of IPs-to-be-avoided is not included as the DNS will not be consulted for raw IPs
# These should be blocked at the firewall.
#echo "Adding 'IP' lines..."
#wget --timeout=20 -qnv -i ${CYGNUS_IPs_LIST} -O  - | sed -e '/\s*#.*$/d' -e '/^\s*$/d' >> ${TMP_FILE}

if [[ -f ${PIHOLE_GRAVITY_LIST} ]]; then
  echo "Absorbing Pi-hole's list..."
  awk '{print $2}' ${PIHOLE_GRAVITY_LIST} >> ${TMP_FILE}
fi

# At this point we have a file that consolidates our own sources and the Pi-hole gravity.list
# Now, we add the user's Black List
if [[ -f ${CYGNUS_LOCALBLACK_LIST} ]]; then
  echo "Consolidating the local BLACKLIST..."
  cat ${CYGNUS_LOCALBLACK_LIST} >> ${TMP_FILE}
fi

# Next we must remove any duplicates and the white-listed sites.
echo "Removing duplicates..."
cat ${TMP_FILE} | sort | uniq > ${CYGNUS_OUTPUT}

rm ${TMP_FILE}
echo "zzzzzz.whitelist.test.zzzzzz" >> ${CYGNUS_OUTPUT}

#
# use tempfiles for fgrep, because pipes can't be used due to conditional executions
#
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
if [[ -f ${CYGNUS_WHITE_LIST} ]]; then
  echo "Applying USS Cygnus's WHITELIST..."
  fgrep -vxFf ${CYGNUS_WHITE_LIST} ${CYGNUS_OUTPUT} > ${TMP_FILE}
fi
mv ${TMP_FILE} ${CYGNUS_OUTPUT}
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)

if [[ -f ${CYGNUS_LOCALWHITE_LIST} ]]; then
  echo "Applying the local WHITELIST..."
  fgrep -vxFf ${CYGNUS_LOCALWHITE_LIST} ${CYGNUS_OUTPUT} > ${TMP_FILE}
fi
mv ${TMP_FILE} ${CYGNUS_OUTPUT}

# Finally the list must be converted to a hosts list: prepending IP4 to each line.
echo "Converting list to hosts format..."
#sed -i -e "s/^/${CYGNUS_IP4}   /" ${CYGNUS_OUTPUT}
awk '{print;print;}' ${CYGNUS_OUTPUT}

echo "Moving list into place..."
# temporary move; while transitioning from Pi-hole to pure dnsmasq
sudo mv ${CYGNUS_OUTPUT} ${PIHOLE_GRAVITY_LIST}
sudo chmod +r ${PIHOLE_GRAVITY_LIST}
sudo chown root:root ${PIHOLE_GRAVITY_LIST}

echo "$(wc -l ${PIHOLE_GRAVITY_LIST} | awk '{print $1}') domains will be blocked"

echo "Restarting DNS to activitate the new list..."
sudo systemctl restart dnsmasq.service
sudo systemctl restart pihole-FTL.service
