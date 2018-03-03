#!/usr/bin/env bash

# V.I.N.CENT

# Find out where we're running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bin/include"

# USS Cygnus allows your own blacklist and will add it if it exists.
CYGNUS_LOCALBLACK_LIST="${CYGNUS_CONFIG_DIR}/black.list"
# USS Cygnus allows your own blacklisted domains and will add it if it exists.
CYGNUS_LOCALBLACKDOMS_LIST="${CYGNUS_CONFIG_DIR}/black.domains"
# USS Cygnus allows your personal whitelist and will process this last of all.
CYGNUS_LOCALWHITE_LIST="${CYGNUS_CONFIG_DIR}/white.list"
# USS Cygnus allows your own whitelisted domains and will add it if it exists.
CYGNUS_LOCALWHITEDOMS_LIST="${CYGNUS_CONFIG_DIR}/white.domains"
# USS Cygnus also comes with it's own whitelist to ensure the source sites don't get blocked
CYGNUS_WHITE_LIST="${SCRIPT_DIR}/white.list"

# Temporary files for storing the intermediate results
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
TMP_HOSTS=$(mktemp /tmp/cygnus.XXXXXX)
TMP_DOMAINS=$(mktemp /tmp/cygnus.XXXXXX)

# Hosts to be blocked
BLOCKED_HOSTS_URL="https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt"
# Domains to be blocked
BLOCKED_DOMS_URL="https://raw.githubusercontent.com/notracking/hosts-blocklists/master/domains.txt"

####### GRABBING THE LIST ######
wget -U 'Mozilla/5.0 (wget)' --timeout=20 -nv "${BLOCKED_HOSTS_URL}" -O "${TMP_HOSTS}" || exit 1
wget -U 'Mozilla/5.0 (wget)' --timeout=20 -nv "${BLOCKED_DOMS_URL}" -O "${TMP_DOMAINS}" || exit 1


####### ADD-ITIONAL SITES ######
# Now, we add the user's black.List
if [[ -f "${CYGNUS_LOCALBLACK_LIST}" ]]; then
  echo "Consolidating the local BLACKLIST..."
  cat "${CYGNUS_LOCALBLACK_LIST}" >> "${TMP_HOSTS}"
fi

# Now, we add the user's black.domains
if [[ -f "${CYGNUS_LOCALBLACKDOMS_LIST}" ]]; then
  echo "Consolidating the local BLACKLISTED DOMAINS..."
  cat "${CYGNUS_LOCALBLACKDOMS_LIST}" >> "${TMP_DOMAINS}"
fi

###### BUT NOT ALL ######
# Next we will remove the white-listed sites.
# use tempfiles for fgrep, because pipes can't be used due to conditional executions
TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
if [[ -f "${CYGNUS_WHITE_LIST}" ]]; then
  echo "Applying USS Cygnus's WHITELIST..."
  grep -vxFf "${CYGNUS_WHITE_LIST}" "${TMP_HOSTS}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${TMP_HOSTS}"
fi

TMP_FILE=$(mktemp /tmp/cygnus.XXXXXX)
if [[ -f "${CYGNUS_LOCALWHITE_LIST}" ]]; then
  echo "Applying the local WHITELIST..."
  grep -vxFf "${CYGNUS_LOCALWHITE_LIST}" "${TMP_HOSTS}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${TMP_HOSTS}"
fi

# code fore whitelisting domains goes here
if [[ -f "${CYGNUS_LOCALWHITEDOMS_LIST}" ]]; then
  echo "Applying the LOCAL WHITE-DOMAINS LIST..."
  grep -vxFf "${CYGNUS_LOCALWHITEDOMS_LIST}" "${TMP_DOMAINS}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${TMP_DOMAINS}"
fi

echo "Moving lists into place..."
sudo mv "${TMP_HOSTS}" "${BLACKHOSTSLIST}"
sudo chmod 744 "${BLACKHOSTSLIST}"
sudo chown root:wheel "${BLACKHOSTSLIST}"

sudo mv "${TMP_DOMAINS}" "${BLACKDOMSLIST}"
sudo chmod 744 "${BLACKDOMSLIST}"
sudo chown root:wheel "${BLACKDOMSLIST}"

echo "$(wc -l ${BLACKHOSTSLIST} | awk '{print $1 "/ 2"}' | bc) hosts will be blocked"
echo "$(wc -l ${BLACKDOMSLIST}  | awk '{print $1 "/ 2"}' | bc) domains will be blocked"

head -n 30 "${BLACKHOSTSLIST}"
echo ":"
tail "${BLACKHOSTSLIST}"
echo ""
head -n 30 "${BLACKDOMSLIST}"
echo ":"
tail "${BLACKDOMSLIST}"

echo "Restarting DNS to activitate the new lists..."

sudo pluginctl dns
