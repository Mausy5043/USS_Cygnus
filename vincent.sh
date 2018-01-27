#!/usr/bin/env bash

# V.I.N.CENT

# Find out where we're running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bin/include"

# USS Cygnus's sources of blocklists are very divers:
# Sources that supply just a list of hostnames, one per line:
CYGNUS_FLAT_LIST="${SCRIPT_DIR}/sources.flat.txt"
# Sources that supply their list formatted as a hosts file:
CYGNUS_127_LIST="${SCRIPT_DIR}/sources.127.txt"
# Sources that supply a list of URLs (we will block the entire domain)
CYGNUS_URL_LIST="${SCRIPT_DIR}/sources.url.txt"
# Sources that supply a list of IPs:
CYGNUS_IPs_LIST="${SCRIPT_DIR}/sources.ip.txt"

# USS Cygnus allows you're own blacklist and will add it if it exists.
CYGNUS_LOCALBLACK_LIST="${CYGNUS_CONFIG_DIR}/black.list"
# USS Cygnus allows you're personal whitelist
CYGNUS_LOCALWHITE_LIST="${CYGNUS_CONFIG_DIR}/white.list"
# USS Cygnus also comes with it's own whitelist
CYGNUS_WHITE_LIST="${SCRIPT_DIR}/white.list"

# Where to put the output
CYGNUS_OUTPUT=$(mktemp /tmp/cygnus.list.XXXXXX)

# A temporary file for storing the intermediate results
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)


####### GROWING THE LIST ######

echo "Fetching 'flat' and '127' lines..."
cat "${CYGNUS_FLAT_LIST}" "${CYGNUS_127_LIST}" | wget --timeout=20 -nv -i - -O "${TMP_FILE}"

echo "Adding 'URL' lines..."
wget --timeout=20 -nv -i "${CYGNUS_URL_LIST}" -O - |\
  sed -e '/\s*#.*$/d' -e '/^\s*$/d' |\
  cut -c8- |\
  awk -F/ '{print $1}' >> "${TMP_FILE}"


# At this point we have a file that consolidates all our sources.
# Now, we add the user's Black List
if [[ -f "${CYGNUS_LOCALBLACK_LIST}" ]]; then
  echo "Consolidating the local BLACKLIST..."
  cat "${CYGNUS_LOCALBLACK_LIST}" >> "${TMP_FILE}"
fi


####### SHRINKING THE LIST #######

# remove duplicates to reduce memory load during filtering
echo "Removing duplicates to conserve memory...(1)"
sort "${TMP_FILE}" | uniq > "${CYGNUS_OUTPUT}"
rm "${TMP_FILE}"

echo "Filtering..."
"${SCRIPT_DIR}"/filter.py "${CYGNUS_OUTPUT}" || ( echo "*** AAARGH!!! ***"; exit 1 )

# remove residual duplicates after filtering
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
echo "Removing duplicates...(2)"
sort "${CYGNUS_OUTPUT}" | uniq > "${TMP_FILE}"
mv "${TMP_FILE}" "${CYGNUS_OUTPUT}"

# The list of IPs-to-be-avoided is not included as the DNS will not be consulted for raw IPs
# These should be blocked at the firewall.
#echo "Adding 'IP' lines..."
#wget --timeout=20 -qnv -i ${CYGNUS_IPs_LIST} -O  - | sed -e '/\s*#.*$/d' -e '/^\s*$/d' >> ${TMP_FILE}

# Next we will remove the white-listed sites.
# use tempfiles for fgrep, because pipes can't be used due to conditional executions
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
if [[ -f "${CYGNUS_WHITE_LIST}" ]]; then
  echo "Applying USS Cygnus's WHITELIST..."
  grep -vxFf "${CYGNUS_WHITE_LIST}" "${CYGNUS_OUTPUT}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${CYGNUS_OUTPUT}"
fi

TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
if [[ -f "${CYGNUS_LOCALWHITE_LIST}" ]]; then
  echo "Applying the local WHITELIST..."
  grep -vxFf "${CYGNUS_LOCALWHITE_LIST}" "${CYGNUS_OUTPUT}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${CYGNUS_OUTPUT}"
fi

# Finally the list must be converted to a hosts list: prepending IP4 and IP6 to each line.
echo "Converting list to hosts format..."
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
awk -v ip4="${BLACKHOLE_IP4}" -v ip6="${BLACKHOLE_IP6}" '{print ip4 "  " $0;print ip6 "  " $0;}' "${CYGNUS_OUTPUT}" > "${TMP_FILE}"
mv "${TMP_FILE}" "${CYGNUS_OUTPUT}"

echo ""
echo ""
head "${CYGNUS_OUTPUT}"
echo ":"
tail "${CYGNUS_OUTPUT}"
echo ""
echo ""

echo "Moving list into place..."
sudo mv "${BLACKLIST}" "${BLACKLIST}.bak"
sudo mv "${CYGNUS_OUTPUT}" "${BLACKLIST}"

sudo chmod 744 "${BLACKLIST}"
sudo chown root:wheel "${BLACKLIST}"

echo "$(wc -l ${BLACKLIST} | awk '{print $1 "/ 2"}' | bc) domains will be blocked"

echo "Restarting DNS to activitate the new list..."

sudo pluginctl dns
