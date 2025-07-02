Build Docker image
```
docker-compose -f docker-compose.bsc.yml build
docker-compose -f docker-compose.cluster.bootstrap.yml build
docker-compose -f docker-compose.cluster.yml build --build-arg OS_ARCH=x86_64
```

Bootstrap cluster
```
docker-compose -f docker-compose.cluster.bootstrap.yml run bootstrap-cluster
```

Start the cluster
```
docker-compose -f docker-compose.cluster.yml up -d cluster-bsc-rpc cluster-bsc-validator1 cluster-bsc-validator2 cluster-bsc-validator3 netstats
```