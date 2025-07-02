Build Docker image
```
docker-compose -f docker-compose.bsc.yml build
docker-compose -f docker-compose.simple.bootstrap.yml build
docker-compose -f docker-compose.simple.yml build --build-arg OS_ARCH=x86_64
```

Bootstrap simple
```
docker-compose -f docker-compose.simple.bootstrap.yml run bootstrap-simple
```

Start the simple
```
docker-compose -f docker-compose.simple.yml up -d bsc-rpc bsc-validator1 netstats
```