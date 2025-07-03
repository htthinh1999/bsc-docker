#!/usr/bin/env bash

workspace=/root

function prepare() {
   if ! [[ -f /usr/local/bin/geth ]];then
        echo "geth do not exist!"
        exit 1
   fi
   rm -rf ${workspace}/storage/*
   cd ${workspace}/genesis
   rm -rf validators.conf
}

function init_validator_data_for_genesis() {
     node_id=$1
     index=$2
     mkdir -p ${workspace}/storage/${node_id}
     # geth --datadir ${workspace}/storage/${node_id} account new   --password /dev/null > ${workspace}/storage/${node_id}Info
     # validatorAddr=`cat ${workspace}/storage/${node_id}Info|grep 'Public address of the key'|awk '{print $6}'`
     validatorAddr=0x$(cat ${workspace}/keys/validator${index}/keystore/* | jq .address | sed 's/"//g')
     powers="0x0000000010000000"
     vote_addr=0x$(cat ${workspace}/keys/bls${index}/bls/keystore/*json | jq .pubkey | sed 's/"//g')
     echo "${validatorAddr},${validatorAddr},${validatorAddr},${powers},${vote_addr}" >> ${workspace}/genesis/validators.conf
     echo ${validatorAddr} > ${workspace}/storage/${node_id}/address
}

function generate_genesis() {
     for ((i=1; i<=${NUMS_OF_VALIDATOR};i++)); do
          for f in ${workspace}/keys/validator${i}/keystore/*; do
               cons_addr="0x$(cat ${f} | jq -r .address)"
               initHolders=${initHolders}","${cons_addr}
          done
     done
     poetry run python -m scripts.generate generate-validators
     poetry run python -m scripts.generate generate-init-holders "${initHolders}"
     poetry run python -m scripts.generate dev \
          --dev-chain-id "${BSC_CHAIN_ID}" \
          --init-burn-ratio "1000" \
          --init-felony-slash-scope "60" \
          --breathe-block-interval "10 minutes" \
          --block-interval "3 seconds" \
          --stake-hub-protector "${INIT_HOLDER}" \
          --unbond-period "2 minutes" \
          --downtime-jail-time "2 minutes" \
          --felony-jail-time "3 minutes" \
          --misdemeanor-threshold "50" \
          --felony-threshold "150" \
          --init-voting-period "2 minutes / BLOCK_INTERVAL" \
          --init-min-period-after-quorum "uint64(1 minutes / BLOCK_INTERVAL)" \
          --governor-protector "${INIT_HOLDER}" \
          --init-minimal-delay "1 minutes" \
          --token-recover-portal-protector "${INIT_HOLDER}"
     # replace the genesis.json with genesis-dev.json
     rm -rf ${workspace}/genesis/genesis.json
     # Remove the 0x prefix from the addresses & empty addresses in alloc section of the genesis.json
     cp ${workspace}/genesis/genesis-dev.json ${workspace}/genesis/genesis.json.backup && jq '.alloc = (.alloc | to_entries | map(select(.key != "") | if (.key | startswith("0x")) then . else {key: ("0x" + .key), value: .value} end) | from_entries)' ${workspace}/genesis/genesis-dev.json > ${workspace}/genesis/genesis_fixed.json && mv ${workspace}/genesis/genesis_fixed.json ${workspace}/genesis/genesis.json
}

function init_genesis_data() {
     node_type=$1
     node_id=$2
     index=$3
     geth --datadir ${workspace}/storage/${node_id} init ${workspace}/genesis/genesis.json
     cp ${workspace}/config/config-${node_type}.toml  ${workspace}/storage/${node_id}/config.toml
     sed -i -e "s/{{NetworkId}}/${BSC_CHAIN_ID}/g" ${workspace}/storage/${node_id}/config.toml
     if [ "${node_id}" == "bsc-rpc" ]; then
          cp ${workspace}/init-holders/* ${workspace}/storage/${node_id}/keystore
          cp ${workspace}/genesis/genesis.json ${workspace}/storage/${node_id}
          cp ${workspace}/config/bootstrap.key ${workspace}/storage/${node_id}/geth/nodekey
     else
          cp ${workspace}/keys/validator${index}/keystore/* ${workspace}/storage/${node_id}/keystore
          cp ${workspace}/keys/validator-nodekey${index} ${workspace}/storage/${node_id}/geth/nodekey
          cp -r ${workspace}/keys/bls${index}/bls ${workspace}/storage/${node_id}/
     fi
}

function init_validator() {
     node_id=$1
     index=$2
     geth --datadir ${workspace}/storage/${node_id} init ${workspace}/genesis/genesis.json > ${workspace}/storage/${node_id}/init.log 2>&1
     cp ${workspace}/config/config-validator.toml  ${workspace}/storage/${node_id}/config.toml
     sed -i -e "s/{{NetworkId}}/${BSC_CHAIN_ID}/g" ${workspace}/storage/${node_id}/config.toml
}

prepare

# First, generate config for each validator
for((i=1;i<=${NUMS_OF_VALIDATOR};i++)); do
     init_validator_data_for_genesis "bsc-validator${i}" ${i}
done

# Then, use validator configs to generate genesis file
generate_genesis

# Finally, use genesis file to init cluster data
init_genesis_data bsc-rpc bsc-rpc

for((i=1;i<=${NUMS_OF_VALIDATOR};i++)); do
     init_genesis_data validator "bsc-validator${i}" ${i}
     init_validator "bsc-validator${i}" ${i}
done