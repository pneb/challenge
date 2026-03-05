#!/bin/bash

set -e
set -x

#define variables
#Old code: # Set KEM to one defined in https://github.com/open-quantum-safe/openssl#key-exchange
#new code start
#KEM names follow the OpenSSL/oqs-provider algorithm list
#Set KEM to one defined by OpenSSL/oqsprovider (e.g. via "openssl list -kem-algorithms -provider oqsprovider -provider default")
#new code end
#ENV variables
[[ -z "$KEM_ALG" ]] && echo "Need to set KEM_ALG" && exit 1;
[[ -z "$SIG_ALG" ]] && echo "Need to set SIG_ALG" && exit 1;
[[ -z "$MEASUREMENT_TIME" ]] && echo "Need to set MEASUREMENT_TIME" && exit 1;

if [[ ! -z "$NETEM_TC" ]]; then
  PORT=eth0
  eval "tc qdisc add dev $PORT root netem $NETEM_TC"
fi

SERVER_IP="$(dig +short server)"

DATETIME=$(date +"%F_%T")

CA_DIR="/opt/shared"

cd "$OPENSSL_PATH" || exit

echo "Running $0 with SIG_ALG=$SIG_ALG and KEM_ALG=$KEM_ALG"

if [ "$CPU_PROFILING" = "True" ]; then
  echo "Will export cpu profiling"
  FG_FREQUENCY=96
  bash -c "perf record -o /out/perf-client.data -F ${FG_FREQUENCY} -C 1 -g" &
  PERF_PID=$!
fi

bash -c "tcpdump -w /out/latencies-post_run${RUN}.pcap src host $SERVER_IP and src port 4433" &
TCPDUMP_PID=$!

echo "{\"tc\": \"$NETEM_TC\", \"kem_alg\": \"$KEM_ALG\", \"sig_alg\": \"$SIG_ALG\"}" > "/out/${DATETIME}_client_run${RUN}.loop"

sleep 5

#old code start
#Run handshakes for $TEST_TIME seconds
#bash -c "taskset -c 1 ${OPENSSL} s_time -curves $KEM_ALG  -connect $SERVER_IP:4433 -new -time $MEASUREMENT_TIME -verify 1 -www '/' -CAfile $CA_DIR/CA.crt > /out/opensslclient_run${RUN}.stdout 2> /out/opensslclient_run${RUN}.stderr"
#old code end

#new code start
#forces the TLS KEM selection to match the experiment variable for each run
#Build a per-run OpenSSL config that sets Groups before running s_time
#set default TLS group via per-run openssl.cnf and run s_time
#see: "https://medium.com/@kochu.mukesh/stunnel-oqsprovider-unlocking-quantum-safe-tls-today-a881a1a04580" and "https://documentation.ubuntu.com/server/explanation/crypto/openssl/"
TMP_OPENSSL_CNF="/tmp/openssl_run${RUN}.cnf"
cp "$OPENSSL_CNF" "$TMP_OPENSSL_CNF"
cat >> "$TMP_OPENSSL_CNF" <<EOF

openssl_conf = openssl_init

[openssl_init]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
Groups = $KEM_ALG
EOF

#Allow rsa:1024 by lowering security level for this run only
if [[ "$SIG_ALG" == "rsa:1024" ]]; then
  echo "CipherString = DEFAULT:@SECLEVEL=0" >> "$TMP_OPENSSL_CNF"
fi
export OPENSSL_CONF="$TMP_OPENSSL_CNF"

bash -c "taskset -c 1 ${OPENSSL} s_time ${OPENSSL_PROVIDER_ARGS} -connect $SERVER_IP:4433 -new -time $MEASUREMENT_TIME -verify 1 -www '/' -CAfile $CA_DIR/CA.crt > /out/opensslclient_run${RUN}.stdout 2> /out/opensslclient_run${RUN}.stderr"
#new code end

if [ "$CPU_PROFILING" = "True" ]
then
    kill $PERF_PID
fi

sleep 30  #Make sure it is finished and written out

kill -2 $TCPDUMP_PID

if [ "$CPU_PROFILING" = "True" ]
then
    perf archive /out/perf-client.data
    echo "CPU profiling data can be found at /out/perf-client.data"
fi

echo "client finished sending $(date), results can be found at /out/results-openssl-$KEM_ALG-$SIG_ALG.txt"
