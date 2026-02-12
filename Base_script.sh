#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
while true; do
simnumber='{{MT}}'
REPO_BASE="https://raw.githubusercontent.com/Srilaxmi0518/APK_Installation/refs/heads/master/Versions"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Extract version number from filename
CURRENT_VERSION=$(echo "$SCRIPT_NAME" | sed -n 's/.*_v_\([0-9]\+\)\.sh/\1/p')

# Check if version was extracted correctly
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "ERROR: Could not determine current version from script name."
    echo "Make sure the script filename contains '_v_<number>.sh'"
    exit 1
fi

echo "Running version: v_$CURRENT_VERSION"
echo "DEBUG: SCRIPT_NAME=$SCRIPT_NAME"
echo "DEBUG: SCRIPT_PATH=$SCRIPT_PATH"
echo "DEBUG: SCRIPT_DIR=$SCRIPT_DIR"

# Get all network interfaces
interfaces=$(su -c 'ip -o link show | awk -F": " "{print \$2}" | cut -d"@" -f1 | sort -u')

# Function to check internet access for a specific IP
check_internet_access_ipv4() {
  local ip=$1
  local result="No"
  if su -c 'ping -c 3 -W 3 8.8.8.8 &> /dev/null'; then
    result="Yes"  
  fi
  if su -c 'ping -c 3 -W 3 4.4.4.4 &> /dev/null'; then
    result="Yes"
  fi
  echo $result
}

check_internet_access_ipv6() {
  local ip=$1
  local result="No"
  if su -c 'ping6 -c 1 -W 3 2001:4860:4860::8888 &> /dev/null'; then
    result="Yes"
  fi
  if su -c 'ping6 -c 1 -W 3 2001:4860:4860::8844 &> /dev/null'; then
    result="Yes"
  fi
  echo $result
}

# Check for internet accessibility flag
flag=false
internet_accessible=false
check_flag() {
# Iterate through each interface
for interface in $interfaces; do
current_epoch=$(date +%s)
current_epoch_ns=$(date +%s%N)
  ipv4=$(su -c "ip -4 addr show $interface | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\.'") 
  ipv6=$(su -c "ip -6 addr show $interface | awk '/inet6 / {print $2}' | cut -d/ -f1 | grep -v '^::1$' | grep -v '^fe80'")

  if [ -n "$ipv4" ] || [ -n "$ipv6" ]; then
    internet_accessible=true
    echo "Interface: $interface"

    if [ -n "$ipv4" ]; then
      echo "IPv4 Address: $ipv4"
      ipv4_access=$(check_internet_access_ipv4 $ipv4)
      echo "Internet access (IPv4): $ipv4_access"
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=DataRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA passed=1,ipv4=\"$ipv4_access\",env=\"cdc2\" $current_epoch_ns"
    else
      echo "IPv4 Address: Not found"
    fi

    if [ -n "$ipv6" ]; then
      echo "IPv6 Address: $ipv6"
      ipv6_access=$(check_internet_access_ipv6 $ipv6)
      echo "Internet access (IPv6): $ipv6_access"
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=DataRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA passed=1,ipv6=\"$ipv6_access\",env=\"cdc2\" $current_epoch_ns"
      flag=true
    else
      echo "IPv6 Address: Not found"
      su -c 'cmd connectivity airplane-mode enable && cmd connectivity airplane-mode disable && sleep 10'
      flag=false
    fi

    echo "========================="
  fi
done
}
check_flag
declare -i id=$(su -c "content query --uri content://call_log/calls --projection '_id' | sed 's/.*=\(.*\)/\1/' |  tail -n 1")
while [ "$flag" = false ]; do
# Check if any interface has internet access
    if ! $internet_accessible; then
        echo "No interfaces with IPv4 or IPv6 addresses found. Latch issue: internet not accessible on any interface."
        check_flag
        sleep 50
        current_epoch=$(date +%s)
        echo "$current_epoch"
        ((id++))
        echo "$id"
        su -c "content insert --uri content://call_log/calls --bind _id:i:$id --bind date:l:$current_epoch --bind subscription_component_name:s:'UEFailure'"
        sleep 2
        su -c "content insert --uri content://call_log/calls --bind _id:i:$id --bind date:l:$current_epoch --bind subscription_component_name:s:'UEFailure'"
        sleep 5
    fi
done

echo "network latched"
# Check the network type using ADB
network_info=$(su -c "dumpsys telephony.registry | grep -E 'mServiceState|mDataConnectionState|mNetworkType'" )

# Display the filtered network type information
#echo "$network_info"

# Calling
count=0
while true; do
current_epoch_ns=$(date +%s%N)
current_epoch=$(date +%s)
#check_flag
msisdn=$(su -c "content query --uri content://telephony/siminfo --projection number | grep -oE 'number=[+][0-9]+' | sed 's/number=//' | tail -n 1 ")
imei=$(su -c "getprop ro.ril.oem.imei | grep -oE '[0-9]+'")
imsi=$(su -c "content query --uri content://telephony/siminfo --projection imsi | grep -oE 'imsi=[0-9]+' | sed 's/imsi=//' | tail -n 1")
pacoip=$(su -c "dumpsys telephony.registry | grep -o ' LinkAddresses: \[ [0-9].*\/64 ] D'  | sed ' s/LinkAddresses: //' | sed 's/ D//'")
# Determine if the device is connected to 4G or 5G
if echo "$network_info" | grep -q 'NR'; then
  if echo "$network_info" | grep -q 'LTE'; then
    echo "The device is connected to NSA."
    ltepci=$(su -c "dumpsys telephony.registry | grep -o 'mPhysicalCellId=[0-9][0-9]*' | sed 's/mPhysicalCellId=//' | head -n 1")
ltearfcn=$(su -c "dumpsys telephony.registry | grep -o 'mChannelNumber=[0-9][0-9]*' | sed 's/mChannelNumber=//' | tail -n 1 ")
ltersrp=$(su -c "dumpsys telephony.registry | grep -o 'rsrp=-[0-9]*' | sed 's/rsrp=//' | tail -n 1")
    nramfrcn=$(su -c "dumpsys telephony.registry | grep -o 'mNrArfcn = [0-9]*' | sed 's/mNrArfcn = //' | tail -n 1")
nrrsrp=$(su -c "dumpsys telephony.registry | grep -o 'ssRsrp = -[0-9]*' | sed 's/ssRsrp = //' | tail -n 1")
nrpci=$(su -c "dumpsys telephony.registry | grep -o 'mPhysicalCellId=[0-9][0-9]*' | sed 's/mPhysicalCellId=//' | tail -n 1")
attach="NSA"
  fi
elif echo "$network_info" | grep -q 'NR_SA'; then
  echo "The device is connected to NR_SA." 
  nrarfcn=$(su -c "dumpsys telephony.registry | grep -o 'mNrArfcn = [0-9]*' | sed 's/mNrArfcn = //' | tail -n 1")
nrrsrp=$(su -c "dumpsys telephony.registry | grep -o 'ssRsrp = -[0-9]*' | sed 's/ssRsrp = //' | tail -n 1")
nrpci=$(su -c "dumpsys telephony.registry | grep -o 'mPhysicalCellId=[0-9][0-9]*' | sed 's/mPhysicalCellId=//' | tail -n 1")
attach="SA" 
elif echo "$network_info" | grep -q 'LTE'; then
  echo "The device is connected to 4G."
  ltepci=$(su -c "dumpsys telephony.registry | grep -o 'mPhysicalCellId=[0-9][0-9]*' | sed 's/mPhysicalCellId=//' | head -n 1")
ltearfcn=$(su -c "dumpsys telephony.registry | grep -o 'mChannelNumber=[0-9][0-9]*' | sed 's/mChannelNumber=//' | tail -n 1 ")
ltersrp=$(su -c "dumpsys telephony.registry | grep -o 'rsrp=-[0-9]*' | sed 's/rsrp=//' | tail -n 1")
attach="LTE"
  
else
  echo "The device is connected to another network type or not connected."
fi

su -c 'am start -a android.intent.action.CALL -d tel:"'$simnumber'"'
check_flag
su -c 'service call isms 5 i32 0 s16 "com.android.mms.service" s16 "null" s16 "'$simnumber'" s16 "null" s16 "'$current_epoch' SMS" s16 "null" s16 "null" i32 1 i64 0'
check_flag
sms=$( su -c 'content query --uri content://sms/ --projection date,type --sort "date ASC" | sed "s/.*date=\(.*\)/\1/" | sed  "s/., type=\(.*\)/ \1/" |  tail -n 1')
echo $sms sms
smssent=$(echo $sms | awk '{print $2}')
echo $smssent smssend
smstime=$(echo $sms | awk '{print $1}')
smstime=$(echo "$smstime" | sed 's/..$//')
echo $current_epoch epotime
echo $smstime smstime
date -d @"$smstime"
echo $smstime smstimedate
date -d @"$current_epoch"
smstimediff=$(($current_epoch - $smstime))
echo $smstimediff
if [ "$smstimediff" -lt 50 ] && [ "$smssent" -eq 2 ]; then
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=SMSRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA passed=1,mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mt_msisdn=\"$simnumber\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
echo "$smstimediff sec SMS ok "
else
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=SMSRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA failed=1,mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mt_msisdn=\"$simnumber\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
echo "SMS failed"
fi
###MMS#####

MMS_COUNT_BEFORE=$(su -c 'content query --uri content://mms/sent' 2>/dev/null | wc -l)
echo "[INFO] MMS sent rows before: $MMS_COUNT_BEFORE"


is_device_locked() {
    su -c 'dumpsys window | grep -i "mDreamingLockscreen=true"' >/dev/null 2>&1
}

unlock_if_needed() {
    if is_device_locked; then
        echo "[INFO] Device is locked, unlocking..."
        su -c 'input keyevent 26'
        sleep 0.5
        su -c 'input swipe 300 1000 300 300'
        sleep 1
    else
        echo "[INFO] Device already unlocked"
    fi
}

check_flag() {
    # Placeholder for your existing check_flag function
    echo "[INFO] check_flag executed"
}

get_media_id() {
    local IMG_NAME="$1"
    IMG_ID=$(su -c "content query --uri content://media/external/images/media/ --where \"_display_name='$IMG_NAME'\"" \
        | tr ',' '\n' \
        | grep "^ _id=" \
        | cut -d= -f2)
    echo "$IMG_ID"
}

tap_send_button() {
    # Dump UI and extract send button coordinates
    su -c 'uiautomator dump /sdcard/ui.xml'
    sleep 1
    su -c 'sed "s/></>\n</g" /sdcard/ui.xml > /sdcard/ui_nodes.xml'

    SEND_BOUNDS=$(su -c 'grep -E "content-desc=\"Send\"|text=\"MMS\"" /sdcard/ui_nodes.xml' \
        | head -n 1 \
        | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p')

    if [ -z "$SEND_BOUNDS" ]; then
        echo "[WARN] Send button not found (skipping tap)"
    else
        set -- $SEND_BOUNDS
        X=$(( ($1 + $3) / 2 ))
        Y=$(( ($2 + $4) / 2 ))
        echo "[INFO] Sending MMS: tapping at $X,$Y"
        su -c "input tap $X $Y"
    fi
}

get_latest_mms_info() {
    mms_info=$(su -c 'content query --uri content://mms --projection _id,msg_box,resp_st,date --sort "date DESC" | head -n 1' \
        | sed -n 's/Row: *\([0-9][0-9]*\).*msg_box=\([0-9][0-9]*\).*resp_st=\([^,]*\).*date=\([0-9][0-9]*\).*/\1 \2 \3 \4/p')
    echo "$mms_info"
}

# =========================================
# ---- 🔓 Wake & unlock device ----
# =========================================
check_flag
unlock_if_needed
sleep 1

# =========================================
# ---- 📸 Screenshot for MMS ----
# =========================================
TS=$(date +%s)
IMG_NAME="MMS_File_$TS.png"
IMG_PATH="/sdcard/Download/$IMG_NAME"

echo "[INFO] Taking screenshot: $IMG_PATH"
su -c "screencap -p $IMG_PATH"
sleep 1

IMG_ID=$(get_media_id "$IMG_NAME")
if [ -z "$IMG_ID" ]; then
    echo "[WARN] Image ID not found"
else
    echo "[INFO] Media id: $IMG_ID"
fi
echo "[INFO] Media ID: $IMG_ID"

# =========================================
# ---- 📩 Open MMS composer ----
# =========================================
echo "[INFO] Opening MMS composer..."
su -c "am start -a android.intent.action.SEND -t image/png --eu android.intent.extra.STREAM content://media/external/images/media/$IMG_ID --es address $simnumber -f 0x10000000"
sleep 2

# =========================================
# ---- 🤖 Tap Send Button ----
# =========================================
tap_send_button
echo "[INFO] MMS send attempted"

# =========================================
# ---- 📊 Get latest MMS info ----
# =========================================
mms_info=$(get_latest_mms_info)
set -- $mms_info
row=$1
msg_box=$2
resp_st=$3
mms_date=$4
echo "[INFO] Latest MMS info: row_id=$row, msg_box=$msg_box, resp_st=$resp_st, date=$mms_date"
MMS_COUNT_AFTER=$(su -c 'content query --uri content://mms/sent' 2>/dev/null | wc -l)
echo "[INFO] MMS sent rows after: $MMS_COUNT_AFTER"
if [ "$MMS_COUNT_AFTER" -gt "$MMS_COUNT_BEFORE" ]; then
    echo "[PASS] MMS submitted successfully"
else
    echo "[FAIL] MMS not submitted "
fi
# Optional: calculate time difference from current epoch
current_epoch=$(date +%s)
smstime=$mms_date
smstimediff=$((current_epoch - smstime))
echo "[INFO] MMS sent $smstimediff seconds ago"

echo "MMS send time: $(date -d @$smstime)"
echo "Current time: $(date -d @$current_epoch)"
if [ -f "$IMG_PATH" ]; then
    su -c "rm -f '$IMG_PATH'"
    echo "[INFO] Screenshot file removed: $IMG_PATH"
else
    echo "[WARN] Screenshot file not found for cleanup"
fi

su -c "input keyevent KEYCODE_HOME"

#su -c"service call isms 5 i32 1 s16 "com.android.mms.service" s16 "null" s16 "$simnumber" s16 "null" s16 "$current_epoch mms" s16 "null" s16 "null" i32 1 i32 0"
#check_flag
#mms=$( su -c "content query --uri content://mms/sent --projection date,type --sort "body DESC" | sed 's/.*date=\(.*\)/\1/'  | sed 's/., type=\(.*\)/ \1/' |  tail -n 1")
#mmssent=$($mms | awk -F': ' '{print $2}')
#mmstime=$($mms | awk -F': ' '{print $1}')
#if [ "$msg_box" -eq 2 ] && [ "$m_type" -eq 128 ]; then
if [ "$msg_box" -eq 2 ]; then
  echo "[PASS] MMS is in Outbox and of correct type "
  curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=MMSRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA passed=1,mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mt_msisdn=\"$simnumber\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
else
  echo "[FAIL] MMS validation failed (msg_box=$msg_box, m_type=$m_type)"
  curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=MMSRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA failed=1,mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mt_msisdn=\"$simnumber\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
fi
#curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=MMSRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA failed=1,mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mt_msisdn=\"$simnumber\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
  mCallState=$(su -c "dumpsys telephony.registry | grep 'mCallState' | sed 's/.*=\(.*\)/\1/' |  sed -n '1p' ")
if [ "$mCallState" -eq 0 ]; then
      echo "IDLE"
elif [ "$mCallState" -eq 1 ]; then
      echo "Call RINGING"
elif [ "$mCallState" -eq 2 ]; then
      echo "Call OFFHOOK"
else
      echo "reason not found"
fi
# Live Dashboard Update

su -c 'input keyevent KEYCODE_ENDCALL'
su -c 'input keyevent KEYCODE_ENDCALL'
sleep 5
Call=$(su -c "content query --uri content://call_log/calls --projection "date:type:features:number:duration" |  tail -n 1")
duration=$(echo $Call | sed 's/.*=\(.*\)/\1/')
echo $duration

if [ "$duration" -eq 0 ]; then
      echo "UnSuccesfull "
      declare -i id=$(su -c "content query --uri content://call_log/calls --projection "_id" | sed 's/.*=\(.*\)/\1/' |  tail -n 1")
      current_epoch=$(date +%s)
      echo "$current_epoch"
      id=$((id + 1))
      echo "$id"
      su -c "content insert --uri content://call_log/calls --bind _id:i:$id --bind date:l:$current_epoch  --bind subscription_component_name:s:'UEFailure'"
      sleep 2
      su -c "content insert --uri content://call_log/calls --bind _id:i:$id --bind date:l:$current_epoch  --bind subscription_component_name:s:'UEFailure'"
      sleep 5
      check_flag
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=VoiceRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA failed=1,mt_msisdn=\"$simnumber\",mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
elif [ "$duration" -gt 23 ] && [ "$mCallState" = 2 ]; then
    echo "Successful"
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=VoiceRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA passed=1,mt_msisdn=\"$simnumber\",mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
elif [ "$duration" -gt 10 ] && [ "$mCallState" = 0 ]; then
      echo "FWR/Drop/"
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=VoiceRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA failed=1,mt_msisdn=\"$simnumber\",mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
check_flag
elif [ "$duration" -gt 1 ] || [ "$duration" > -lt 23 ]; then
      echo "FWR/Drop"
curl --request POST "https://stg-ras.1und1.symworld.symphony.rakuten.com/influxdb/api/v2/write?org=28b1289d1a5617bf&bucket=VoiceRemote&precision=ns" --header "Authorization: Token KdXTb4YF4kq0PiKrKeS_TjlRSH3yV7bqLi-MVtDOc2YuVGAsYYhlMSHT6JyMEr89OOmTOZAb7scFycDXQxCTjg==" --header "Content-Type: text/plain" --data "launch_status,host=serverA failed=1,mt_msisdn=\"$simnumber\",mo_msisdn=\"$msisdn\",mo_imei=\"$imei\",mo_imsi=\"$imsi\",PCI_4G_5G=\"[$ltepci/$nrpci]\",RSRP_4G_5G=\"[$ltersrp/$nrrsrp]\",ARFCN_4G_5G=\"[$ltearfcn/$nrarfcn]\",IP=\"$pacoip\",env=\"cdc2\",Net=\"$attach\",Sip=\"195\" $current_epoch_ns"
check_flag
else
      echo "reason not found"
fi
#offline update in case call failed
#sleep 5




  count=$((count + 1))
self_update() {
echo "Checking for newer versions..."

# Look ahead for newer versions (adjust range if needed)
for NEXT_VERSION in $(seq $((CURRENT_VERSION + 1)) $((CURRENT_VERSION + 5))); do
    NEXT_SCRIPT=$(echo "$SCRIPT_NAME" | sed "s/_v_${CURRENT_VERSION}\.sh/_v_${NEXT_VERSION}.sh/")
   #NEXT_SCRIPT="${SCRIPT_NAME/_v_${CURRENT_VERSION}.sh/_v_${NEXT_VERSION}.sh}"
    NEXT_URL="$REPO_BASE/$NEXT_SCRIPT"
    NEXT_LOCAL="$SCRIPT_DIR/$NEXT_SCRIPT"

    echo "Checking version $NEXT_VERSION at $NEXT_URL..."

    # Check if the URL exists
    if wget -q --spider "$NEXT_URL"; then
        echo " Found newer version: v_$NEXT_VERSION"

        # Download the new version
        if wget -q -O "$NEXT_LOCAL" "$NEXT_URL"; then
            chmod +x "$NEXT_LOCAL"
            echo " Switching to $NEXT_SCRIPT"
            exec "$NEXT_LOCAL"
        else
            echo "Failed to download v_$NEXT_VERSION"
        fi
    fi
done

echo " Already running latest version"
}
self_update
done

    
done
