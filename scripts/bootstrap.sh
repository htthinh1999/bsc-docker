#!/usr/bin/env bash

workspace=$(cd `dirname $0`; pwd)/..

function prepare() {
   if ! [[ -f /usr/local/bin/geth ]];then
        echo "geth do not exist!"
        exit 1
   fi
   rm -rf ${workspace}/storage/*
   cd ${workspace}/genesis
   rm -rf validators.conf
}

function init_validator() {
     node_id=$1
     mkdir -p ${workspace}/storage/${node_id}
     geth --datadir ${workspace}/storage/${node_id} account new   --password /dev/null > ${workspace}/storage/${node_id}Info
     validatorAddr=`cat ${workspace}/storage/${node_id}Info|grep 'Public address of the key'|awk '{print $6}'`

     echo "${validatorAddr},${validatorAddr},${validatorAddr},0x0000000010000000,0x85e6972fc98cd3c81d64d40e325acfed44365b97a7567a27939c14dbc7512ddcf54cb1284eb637cfa308ae4e00cb5588" >> ${workspace}/genesis/validators.conf
     echo ${validatorAddr} > ${workspace}/storage/${node_id}/address
}

function generate_genesis() {
     INIT_HOLDER_ADDRESSES=$(ls ${workspace}/init-holders | tr '\n' ',')
     poetry run python -m scripts.generate generate-validators
     poetry run python -m scripts.generate generate-init-holders "${INIT_HOLDER_ADDRESSES}"
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
}

function init_genesis_data() {
     node_type=$1
     node_id=$2
     geth --datadir ${workspace}/storage/${node_id} init ${workspace}/genesis/genesis.json
     cp ${workspace}/config/config-${node_type}.toml  ${workspace}/storage/${node_id}/config.toml
     sed -i -e "s/{{NetworkId}}/${BSC_CHAIN_ID}/g" ${workspace}/storage/${node_id}/config.toml
     if [ "${node_id}" == "bsc-rpc" ]; then
          cp ${workspace}/init-holders/* ${workspace}/storage/${node_id}/keystore
          cp ${workspace}/genesis/genesis.json ${workspace}/storage/${node_id}
          cp ${workspace}/config/bootstrap.key ${workspace}/storage/${node_id}/geth/nodekey
     fi
}

prepare

# First, generate config for each validator
for((i=1;i<=${NUMS_OF_VALIDATOR};i++)); do
     init_validator "bsc-validator${i}"
done

# Then, use validator configs to generate genesis file
generate_genesis

# Finally, use genesis file to init cluster data
init_genesis_data bsc-rpc bsc-rpc

for((i=1;i<=${NUMS_OF_VALIDATOR};i++)); do
     init_genesis_data validator "bsc-validator${i}"
done