#!/bin/sh

# You can override the following variables with environment variables (for example from docker-compose)

# true to accept EULA of speedtest, setting this to false prevents the program from running
ACCEPT_EULA="${ACCEPT_EULA:-false}"

# true if you want the program to run forever, false if you want to run it only one time
LOOP="${LOOP:-false}"

# how much to wait between one run and the next one, used only when LOOP is set to true
LOOP_DELAY="${LOOP_DELAY:-60}"

# true to save the results in InfluxDB, false to ignore saving
DB_SAVE="${DB_SAVE:-false}"

# all the InfluxDB settings to save data
DB_HOST="${DB_HOST:-http://localhost:8086}"
DB_ORG="${DB_ORG:-your_org}"
DB_BUCKET="${DB_BUCKET:-speedtest}"
DB_TOKEN="${DB_TOKEN:-your_token}"
DB_EXTRA_TAGS="${DB_EXTRA_TAGS}"

check_eula()
{
    if ! $ACCEPT_EULA
    then
        echo "Please set the ACCEPT_EULA environment variable to true to allow the program to run."
        echo "Exiting..."
        exit 1
    fi
}

run_speedtest()
{
    # capture the current date and time
    DATE=$(date +%s)

    # start the speedtest and save the results into a variable
    echo "[$(date)] - Running speedtest..."
    JSON=$(speedtest --accept-license --accept-gdpr -f json)

    # extract all the data from the json result
    DATA_TIMESTAMP="$(echo $JSON | jq -r '.timestamp')"
    DATA_UNIX_TIMESTAMP="$(date -d $DATA_TIMESTAMP +"%s")"
    
    DATA_PING_JITTER="$(echo $JSON | jq -r '.ping.jitter')"
    DATA_PING_LATENCY="$(echo $JSON | jq -r '.ping.latency')"
    DATA_PING_LOW="$(echo $JSON | jq -r '.ping.low')"
    DATA_PING_HIGH="$(echo $JSON | jq -r '.ping.high')"    

    DATA_DOWNLOAD_BANDWITH="$(echo $JSON | jq -r '.download.bandwidth')"
    DATA_DOWNLOAD_BYTES="$(echo $JSON | jq -r '.download.bytes')"
    DATA_DOWNLOAD_ELAPSED="$(echo $JSON | jq -r '.download.elapsed')"
    DATA_DOWNLOAD_LATENCY_IQM="$(echo $JSON | jq -r '.download.latency.iqm')"
    DATA_DOWNLOAD_LATENCY_LOW="$(echo $JSON | jq -r '.download.latency.low')"
    DATA_DOWNLOAD_LATENCY_HIGH="$(echo $JSON | jq -r '.download.latency.high')"
    DATA_DOWNLOAD_LATENCY_JITTER="$(echo $JSON | jq -r '.download.latency.jitter')"

    DATA_UPLOAD_BANDWITH="$(echo $JSON | jq -r '.upload.bandwidth')"
    DATA_UPLOAD_BYTES="$(echo $JSON | jq -r '.upload.bytes')"
    DATA_UPLOAD_ELAPSED="$(echo $JSON | jq -r '.upload.elapsed')"
    DATA_UPLOAD_LATENCY_IQM="$(echo $JSON | jq -r '.upload.latency.iqm')"
    DATA_UPLOAD_LATENCY_LOW="$(echo $JSON | jq -r '.upload.latency.low')"
    DATA_UPLOAD_LATENCY_HIGH="$(echo $JSON | jq -r '.upload.latency.high')"
    DATA_UPLOAD_LATENCY_JITTER="$(echo $JSON | jq -r '.upload.latency.jitter')"

    DATA_PACKETLOSS="$(echo $JSON | jq -r '.packetLoss')"

    DATA_ISP="$(echo $JSON | jq -r '.isp')"

    DATA_INTERFACE_INTERNALIP="$(echo $JSON | jq -r '.interface.internalIp')"
    DATA_INTERFACE_NAME="$(echo $JSON | jq -r '.interface.name')"
    DATA_INTERFACE_MACADDR="$(echo $JSON | jq -r '.interface.macAddr')"
    DATA_INTERFACE_ISVPN="$(echo $JSON | jq -r '.interface.isVpn')"
    DATA_INTERFACE_EXTERNALIP="$(echo $JSON | jq -r '.interface.externalIp')"

    DATA_SERVER_ID="$(echo $JSON | jq -r '.server.id')"
    DATA_SERVER_HOST="$(echo $JSON | jq -r '.server.host')"
    DATA_SERVER_PORT="$(echo $JSON | jq -r '.server.port')"
    DATA_SERVER_NAME="$(echo $JSON | jq -r '.server.name')"
    DATA_SERVER_LOCATION="$(echo $JSON | jq -r '.server.location')"
    DATA_SERVER_COUNTRY="$(echo $JSON | jq -r '.server.country')"
    DATA_SERVER_IP="$(echo $JSON | jq -r '.server.ip')"

    DATA_RESULT_ID="$(echo $JSON | jq -r '.result.id')"
    DATA_RESULT_URL="$(echo $JSON | jq -r '.result.url')"
    DATA_RESULT_PERSISTED="$(echo $JSON | jq -r '.result.persisted')"
    
    # print some basic data to stdout
    echo "[$(date)] - Download: $(($DATA_DOWNLOAD_BANDWITH / 125000 )) Mbps ($DATA_DOWNLOAD_BANDWITH bytes/s)"
    echo "[$(date)] - Upload: $(($DATA_UPLOAD_BANDWITH / 125000 )) Mbps ($DATA_UPLOAD_BANDWITH bytes/s)"
    echo "[$(date)] - Ping: $DATA_PING_LATENCY ms"

    # save results to InfluxDB
    if $DB_SAVE;
    then
        echo "[$(date)] - Writing data to InfluxDB..."

        LINE_PROTOCOL_TAGS="isp=$DATA_ISP,interface_internalip=$DATA_INTERFACE_INTERNALIP,interface_name=$DATA_INTERFACE_NAME,interface_macaddr=$DATA_INTERFACE_MACADDR,interface_isvpn=$DATA_INTERFACE_ISVPN,interface_externalip=$DATA_INTERFACE_EXTERNALIP,server_id=$DATA_SERVER_ID,server_host=$DATA_SERVER_HOST,server_port=$DATA_SERVER_PORT,server_name=$DATA_SERVER_NAME,server_location=$DATA_SERVER_LOCATION,server_country=$DATA_SERVER_COUNTRY,server_ip=$DATA_SERVER_IP"

        if [ ! -z "$DB_EXTRA_TAGS" ]
        then
            LINE_PROTOCOL_TAGS="$LINE_PROTOCOL_TAGS,$DB_EXTRA_TAGS"
        fi

        LINE_PROTOCOL_TAGS="$(echo $LINE_PROTOCOL_TAGS | sed 's/ /\\ /g')"
        LINE_PROTOCOL_FIELDS="ping_jitter=$DATA_PING_JITTER,ping_latency=$DATA_PING_LATENCY,ping_low=$DATA_PING_LOW,ping_high=$DATA_PING_HIGH,download_bandwith=$DATA_DOWNLOAD_BANDWITH,download_bytes=$DATA_DOWNLOAD_BYTES,download_elapsed=$DATA_DOWNLOAD_ELAPSED,download_latency_iqm=$DATA_DOWNLOAD_LATENCY_IQM,download_latency_low=$DATA_DOWNLOAD_LATENCY_LOW,download_latency_high=$DATA_DOWNLOAD_LATENCY_HIGH,download_latency_jitter=$DATA_DOWNLOAD_LATENCY_JITTER,upload_bandwith=$DATA_UPLOAD_BANDWITH,upload_bytes=$DATA_UPLOAD_BYTES,upload_elapsed=$DATA_UPLOAD_ELAPSED,upload_latency_iqm=$DATA_UPLOAD_LATENCY_IQM,upload_latency_low=$DATA_UPLOAD_LATENCY_LOW,upload_latency_high=$DATA_UPLOAD_LATENCY_HIGH,upload_latency_jitter=$DATA_UPLOAD_LATENCY_JITTER,packetloss=$DATA_PACKETLOSS,result_id=\"$DATA_RESULT_ID\",result_url=\"$DATA_RESULT_URL\",result_persisted=$DATA_RESULT_PERSISTED"

        curl -s -S -XPOST "$DB_HOST/api/v2/write?org=$DB_ORG&bucket=$DB_BUCKET&precision=s" \
            --header "Authorization: Token $DB_TOKEN" \
            --header "Content-Type: text/plain; charset=utf-8" \
            --header "Accept: application/json" \
            --data-binary "network_speed,$LINE_PROTOCOL_TAGS $LINE_PROTOCOL_FIELDS $DATA_UNIX_TIMESTAMP"
    fi

    echo "[$(date)] - Speed test finished"
}

check_eula

if $LOOP;
then
    while :
    do
        run_speedtest
        echo "[$(date)] - Next speedtest will run in ${LOOP_DELAY}s"
        sleep $LOOP_DELAY
    done
else
    run_speedtest
fi
