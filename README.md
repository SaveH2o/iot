# iot
IoT cluster on Google Cloud Platform. Supposing that your already have a running cluster there.

## Pre-requisites

* [Helm3](https://helm.sh/docs/intro/install/ "Helm Installation"): to avoid Tiller
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/ "Kubectl Installation")

## Get started

Clone the repo and type "make" to get help.

    make

## Deploy All

Currently **core** and **db** only. There is no automatic **provision**, it's expected you bring your own cluster.

    make all

## Core Applications

Deploy core applications into the cluster, including the latest prometheus-community/kube-prometheus-stack. 

    make core

* **Prometheus-Operator**: orchestrates the lifecycle for prometheus components and deploys a time-series database that scales incredibly well.
* **Grafana**: is a powerful visualization tool we will use for displaying our metrics. This could be considered the 'frontend' of our application.
* **PushGateway**: is a 'sink' or 'buffer' for metric data that is too short lived for Prometheus to scrape. This is what our cron jobs will log data to since the containers wont live long enough for Prometheus to ever see them.
* **Kubernetes Dashboard**: The oficial dashboard for Kubernetes, updated to v2.04.

Also available individual commands:

    make prometheus
    make dashboard
    make kill-prometheus
    make kill-dashboard
    make pushgateway

## Database

Deploy Cassandra and DataStax Studio, based on a ConfigMap.

    make db

* **Cassandra-Operator**: Cassandra Database, based on [DataStax Cassandra Docs](https://docs.datastax.com/en/cass-operator/doc/cass-operator/cassOperatorGettingStarted.html).
* **Datastax Studio**: The development tool may be embedded into the cluster.

## Proxies

Deploy/kill proxies for all applications.

    make proxies
    make kill-proxies

Currently following proxies are available:

- http://localhost:8001 dashboard
- http://localhost:9090 prometheus
- http://localhost:9093 alertmanager
- http://localhost:8080 grafana
- http://localhost:9091 studio

## Provision Cluster

Provision a Civo K3s cluster.

    make provision

If issues with *civo create* stalls the remote provision, try creating an empty cluster first using civo.com and fill properly the CIVO_TOKEN in the .env file, for example:

    CIVO_TOKEN=wGd9xxx-xxxxxxxxxx-xxxxxxx8PqxE2shygAjCJ
    SLACK_URL=https://hooks.slack.com/services/xxx/xxx/xxx
    ADMIN_PASSWORD=xxx
    WIO1=xxx
    WIO2=xxx
    WIO3=xxx
