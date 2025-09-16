#!/bin/bash

PASSWORD="deluge"

#Ensure web session timeout is set to maximum
sed -i 's/"session_timeout": [0-9]\+/"session_timeout": 999999999/' /config/web.conf

deluge_web_connected() {
if [ ! -f /tmp/cookies.txt ]; then
  # login
  curl -s -c /tmp/cookies.txt \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"method\": \"auth.login\", \"params\": [\"$PASSWORD\"], \"id\": 1}" \
    http://localhost:8112/json > /dev/null 
fi

# check connected state
curl -s -b /tmp/cookies.txt \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"method": "web.update_ui", "params": [["name","hash","progress"], {}], "id": 2}' \
  http://localhost:8112/json | jq .result.connected
}

PYTHONWARNINGS="ignore" deluge-console -c /config/ info > /tmp/info

DL_HASHES=$(awk '/^\[D\]/ {print $NF}' /tmp/info)
PREVIOUS_HASHES=$(awk '/^\[D\]/ {print $NF}' /tmp/prev_info 2>/dev/null || echo "")

readarray -t dl <<<"$DL_HASHES"
readarray -t prev <<<"$PREVIOUS_HASHES"

NEW_HASHES=()

for h in "${dl[@]}"; do
    if ! printf "%s\n" "${prev[@]}" | grep -qx "$h"; then
        NEW_HASHES+=("$h")
    fi
done

NEW_COUNT=${#NEW_HASHES[@]}

cp /tmp/info /tmp/prev_info

i=0                                                                
while [[ "$(deluge_web_connected)" == "false" && $i -le 2 ]]      
  do                                                                 
    echo "Deluge Web not connected → Re-starting Deluge Web"
    pkill -x 'deluge-web'                                          
    sleep 10                                                       
    i=$((i+1))                                                     
done

if (( NEW_COUNT > 0 )); then
    echo "Found $NEW_COUNT new torrent(s):"
    for h in "${NEW_HASHES[@]}"; do
      printf "  %s\n" "$h" 
    done

    PYTHONWARNINGS="ignore" deluge-console -c /config/ status > /tmp/status
    DL_SPEED=$(awk '/Total download/ {print $3}' /tmp/status)
    QUEUE=$(awk '/Downloading/ {print $2}' /tmp/status)

    DL_SPEED_INT=${DL_SPEED%%.*}
    echo "Download speed ${DL_SPEED}"
    if (( QUEUE > 0 && DL_SPEED_INT < 1 )); then
        echo "Client stalled → Re-starting Deluge."
        PYTHONWARNINGS="ignore" deluge-console -c /config/ halt
        pkill -x 'deluge-web'
        exit 1
    fi
fi

echo "Deluge is healthy"
exit 0
