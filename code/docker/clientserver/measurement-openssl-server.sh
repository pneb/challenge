#!/bin/bash

set -e
set -x

#old code start
#Set KEM to one defined in https://github.com/open-quantum-safe/openssl#key-exchange
#old code end

#new code start
#KEM names follow the OpenSSL/oqs-provider algorithm list
#Set KEM to one defined by OpenSSL/oqsprovider (e.g. via "openssl list -kem-algorithms -provider oqsprovider -provider default")
#new code end
[[ -z "$KEM_ALG" ]] && echo "Need to set KEM_ALG" && exit 1;
[[ -z "$SIG_ALG" ]] && echo "Need to set SIG_ALG" && exit 1;

if [[ ! -z "$NETEM_TC" ]]; then
  PORT=eth0
  eval "tc qdisc add dev $PORT root netem $NETEM_TC"
fi

SERVER_IP="$(dig +short server)"
DATETIME=$(date +"%F_%T")

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
#new code end

CA_DIR="/opt/shared/"

cd "${OPENSSL_PATH}"/bin

#new code start
# generate CA key and cert
${OPENSSL} req ${OPENSSL_PROVIDER_ARGS} -x509 -new -newkey "${SIG_ALG}" -keyout CA.key -out CA.crt -nodes -subj "/CN=oqstest CA" -days 365
#new code end

cp CA.crt $CA_DIR

cp CA.crt /out/CA_run${RUN}.crt
cp CA.key /out/CA_run${RUN}.key
SERVER_CRT=/out/server_run${RUN}

#old code start
#Optionally set server certificate alg to one defined in https://github.com/open-quantum-safe/openssl#authentication
#The root CA's signature alg remains as set when building the image
#old code end

#generate new server CSR using pre-set CA.key & cert
#old code start
#${OPENSSL} req -new -newkey "${SIG_ALG}" -keyout $SERVER_CRT.key -out $SERVER_CRT.csr -nodes -subj "/CN=$IP"
#old code end

#new code start
#Generate the server CSR with provider args so oqs algorithms are available
${OPENSSL} req ${OPENSSL_PROVIDER_ARGS} -new -newkey "${SIG_ALG}" -keyout $SERVER_CRT.key -out $SERVER_CRT.csr -nodes -subj "/CN=$IP"
#new code end

# generate server cert
#old code start
#${OPENSSL} x509 -req -in $SERVER_CRT.csr -out $SERVER_CRT.crt -CA CA.crt -CAkey CA.key -CAcreateserial -days 365
#old code end

#new code start
#sign the server cert with provider args so oqs algorithms are available
${OPENSSL} x509 ${OPENSSL_PROVIDER_ARGS} -req -in $SERVER_CRT.csr -out $SERVER_CRT.crt -CA CA.crt -CAkey CA.key -CAcreateserial -days 365
#new code end

echo "starting experiment: $(date)"

echo "Server has IP $SERVER_IP"

echo "{\"tc\": \"$NETEM_TC\", \"kem_alg\": \"$KEM_ALG\", \"sig_alg\": \"$SIG_ALG\"}" > "/out/${DATETIME}_server_run${RUN}.loop"

bash -c "tcpdump -w /out/latencies-pre_run${RUN}.pcap dst host $SERVER_IP and dst port 4433" &
TCPDUMP_PID=$!

if [ "$CPU_PROFILING" = "True" ]
then
  echo "will save cpu profiling"
  FG_FREQUENCY=96
  bash -c "perf record -o /out/perf-dut.data -F ${FG_FREQUENCY} -C 1 -g" &
  PERF_PID=$!
fi

#start a TLS1.3 test server based on openssl accepting only the specified KEM_ALG
#old code start
#bash -c "taskset -c 1 ${OPENSSL} s_server -cert $SERVER_CRT.crt -key $SERVER_CRT.key -curves $KEM_ALG -www -tls1_3 -accept $CLIENT_IP:4433"
#old code end

#new code start
#Run s_server with provider args and -groups to select the TLS KEM
bash -c "taskset -c 1 ${OPENSSL} s_server ${OPENSSL_PROVIDER_ARGS} -cert $SERVER_CRT.crt -key $SERVER_CRT.key -curves $KEM_ALG -www -tls1_3 -accept $CLIENT_IP:4433"
#new code end

sleep 30

kill -2 $TCPDUMP_PID

if [ "$CPU_PROFILING" = "True" ]
then
    kill $PERF_PID
    sleep 30
    perf archive /out/perf-client.data
    echo "CPU profiling data can be found at /out/perf-client.data"
fi
