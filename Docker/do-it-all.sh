#!/bin/sh

###
# These commands are not necessarily meant to be run
# as a script, I run them one at a time by copying and
# pasting.  You could add checks in after starting
# Elasticsearch and also after starting Kibana to make
# sure that things are started up before continuing.
# See healthstate.sh
###

# There are multiple ways of setting up networking 
# between Docker containers.
# At the time of writing, creating a shared network 
# is the preferred method.

docker network create course_stack

echo "Do you wish to remove any existing containers named elasticsearch, kibana, metricbeat, and filebeat?"
select ynq in "Yes" "No" "Quit"; do
    case $ynq in
        Yes ) docker rm -f elasticsearch  kibana  metricbeat  filebeat; break;;
        No ) echo "Continuing ..."; break;;
        Quit ) exit;;
    esac
done

# Note that I am adding labels for hint based Beats autodiscover, 
# if you run Filebeat and Metricbeat and configure them for hints 
# based autodiscover then the Elasticsearch and Kibana logs and 
# metrics will be automatically discovered and processed with their 
# respective modules.  This is a dev/demo configuration of 
# Elasticsearch, see the docs for a production Docker run command

echo "Deploying Elasticsearch\n"

docker run -d \
  --name=elasticsearch \
  --label co.elastic.logs/module=elasticsearch \
  --env="discovery.type=single-node" \
  --env="ES_JAVA_OPTS=-Xms256m -Xmx256m" \
  --env="ELASTIC_PASSWORD=foo" \
  --env="xpack.license.self_generated.type=trial" \
  --env="xpack.security.enabled=true" \
  --env="xpack.ml.enabled=false" \
  --network=course_stack \
  -p 9300:9300 -p 9200:9200 \
  --health-cmd='curl -s -f --user elastic:foo http://localhost:9200/_cat/health' \
  docker.elastic.co/elasticsearch/elasticsearch:7.6.0

./healthstate.sh elasticsearch

# This starts Kibana.  Do not run this until Elasticsearch 
# is healthy (docker ps)

echo "Deploying Kibana\n"
docker run -d \
  --name=kibana \
  --user=kibana \
  --network=course_stack -p 5601:5601 \
  --health-cmd='curl -s -f --user elastic:foo http://localhost:5601/login' \
  --label co.elastic.logs/module=kibana \
  --label co.elastic.metrics/module=kibana \
  --label co.elastic.metrics/hosts='${data.host}:${data.port}' \
  --env="XPACK_SECURITY_ENABLED=true" \
  --env="XPACK_ML_ENABLED=true" \
  --env="ELASTICSEARCH_USERNAME=elastic" \
  --env="ELASTICSEARCH_PASSWORD=foo" \
  docker.elastic.co/kibana/kibana:7.6.0

./healthstate.sh kibana

echo "Deploying Metricbeat\n"
docker run \
  --network=course_stack \
  docker.elastic.co/beats/metricbeat:7.6.0 \
  setup -E setup.kibana.host=kibana:5601 \
  -E output.elasticsearch.hosts=["elasticsearch:9200"] \
  -E output.elasticsearch.username="elastic" \
  -E output.elasticsearch.password="foo"

docker run -d \
  --name=metricbeat \
  --network=course_stack \
  --user=root \
  --volume="$(pwd)/metricbeat.docker.yml:/usr/share/metricbeat/metricbeat.yml:ro" \
  --volume="/sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro" \
  --volume="/proc:/hostfs/proc:ro" \
  --volume="/:/hostfs:ro" \
  --volume="/var/run/docker.sock:/var/run/docker.sock:ro" \
  docker.elastic.co/beats/metricbeat:7.6.0 \
  -e -strict.perms=false \
  -E output.elasticsearch.hosts=["elasticsearch:9200"] \
  -E output.elasticsearch.username="elastic" \
  -E output.elasticsearch.password="foo"



echo "Deploying Filbeat\n"

docker run \
  --network=course_stack \
  docker.elastic.co/beats/filebeat:7.6.0 \
  setup -E setup.kibana.host=kibana:5601 \
  -E output.elasticsearch.hosts=["elasticsearch:9200"] \
  -E output.elasticsearch.username="elastic" \
  -E output.elasticsearch.password="foo"

curl -L -O https://raw.githubusercontent.com/elastic/beats/6.6/deploy/docker/filebeat.docker.yml

docker run -d \
  --name=filebeat \
  --network=course_stack \
  --user=root \
  --volume="$(pwd)/filebeat.docker.yml:/usr/share/filebeat/filebeat.yml:ro" \
  --volume="/var/lib/docker/containers:/var/lib/docker/containers:ro" \
  --volume="/var/run/docker.sock:/var/run/docker.sock:ro" \
  docker.elastic.co/beats/filebeat:7.6.0 \
  -e -strict.perms=false \
  -E output.elasticsearch.hosts=["elasticsearch:9200"] \
  -E output.elasticsearch.username="elastic" \
  -E output.elasticsearch.password="foo"

echo "Open a browser to http://localhost:5601/"

