#include .env

KUBECONFIG := --kubeconfig $$HOME/.kube/config
KUBECTL := kubectl $(KUBECONFIG)
HELM := helm $(KUBECONFIG)

# Kubernetes dashboard v2.0.0-rc5 released 3 set 2020
DASHBOARD = "https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.4/aio/deploy/recommended.yaml"

# Namespaces
MONITORING = monitoring			  # Prometheus monitoring
STUDIO = studio					  # Datastax Studio
CASSANDRA = cass-operator		  # Cassandra Operator

.DEFAULT_GOAL := help
.PHONY: all

all:                              ## Deploy stack in a empty cluster
all: core db

##########################################################
##@ CLUSTER
##########################################################
.PHONY: dashboard-config 

dashboard-config:
	@$(KUBECTL) -n kubernetes-dashboard describe secret admin-user-token | grep ^token

##########################################################
##@ DATABASE
##########################################################
.PHONY: db cassandra configmap studio

db: cassandra configmap studio    ## Deploy Cassandra, ConfigMap and Studio

cassandra:                        ## Deploy Cassandra Operator
	@$(info Deploying Cassandra Operator)
	@$(KUBECTL) create -f https://raw.githubusercontent.com/datastax/cass-operator/v1.4.1/docs/user/cass-operator-manifests-v1.16.yaml
	@$(KUBECTL) create -f https://raw.githubusercontent.com/datastax/cass-operator/v1.4.1/operator/k8s-flavors/gke/storage.yaml
	@sleep 5
	@$(KUBECTL) -n $(CASSANDRA) create -f https://raw.githubusercontent.com/datastax/cass-operator/v1.4.1/operator/example-cassdc-yaml/dse-6.8.x/example-cassdc-minimal.yaml

configmap:                        ## Deploy ConfigMap
	@cat deploy/cassandra/05-configMap.yaml | \
		sed "s/superuserpassword/$(shell $(KUBECTL) get secret cluster2-superuser -n $(CASSANDRA) -o yaml | grep -m1 -Po 'password: \K.*' | base64 -d && echo "")/" - \
		> deploy/cassandra/configMap.yaml

studio:                           ## Deploy Studio
	@$(KUBECTL) create namespace $(STUDIO) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	@$(KUBECTL) -n $(STUDIO) apply -f deploy/cassandra/configMap.yaml
	@$(KUBECTL) -n $(STUDIO) apply -f deploy/cassandra/studio.yaml

##########################################################
##@ CORE APPS
##########################################################
.PHONY: core dashboard prometheus pushgateway

core:                             ## Deploy core applications
core: dashboard prometheus pushgateway

dashboard:
	@$(info Deploying Dashboard)
	@$(KUBECTL) create -f $(DASHBOARD)
	@$(KUBECTL) create -f deploy/dashboard/dashboard.admin-user.yaml -f deploy/dashboard/dashboard.admin-user-role.yaml

prometheus:                       ## Deploy Prometheus Operator
	@$(info Deploying Prometheus Operator)
	@$(KUBECTL) create namespace $(MONITORING) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	@$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@$(HELM) repo add stable https://kubernetes-charts.storage.googleapis.com/
	@$(HELM) repo update
	@$(HELM) install prometheus prometheus-community/kube-prometheus-stack \
		--namespace $(MONITORING) \
		--wait

pushgateway:                      ## Deploy Prometheus Push Gateway
	$(info Deploying Prometheus Push Gateway)
	$(HELM) repo update
	$(HELM) upgrade --install \
		--create-namespace $(MONITORING) \
		--values deploy/pushgateway/values.yaml \
		--version 1.3.0 \
		--wait \
		metrics-sink stable/prometheus-pushgateway
	
##########################################################
##@ UTIL
##########################################################
.PHONY: proxies kill-proxies kill-prometheus kill-dashboard kill-studio help cron-connector

proxies:                          ## Proxy all services
	# @echo http://localhost:8001 dashboard
	# @echo http://localhost:9090 prometheus
	# @echo http://localhost:9093 alertmanager
	# @echo http://localhost:8080 grafana
	@echo http://localhost:9091 studio

	# @$(KUBECTL) proxy &
	# @$(KUBECTL) port-forward -n $(MONITORING) $(shell $(KUBECTL) get pods -n $(MONITORING) -l "app=prometheus" -o name)  9090:9090 &
	# @$(KUBECTL) port-forward -n $(MONITORING) $(shell $(KUBECTL) get pods -n $(MONITORING) -l "app=alertmanager" -o name)  9093:9093 &
	# @$(KUBECTL) port-forward -n $(MONITORING) svc/prometheus-grafana 8080:80 &
	@$(KUBECTL) port-forward -n $(STUDIO) $(shell $(KUBECTL) get pods -n $(STUDIO) -l "app=studio-lb" -o name)  9091:9091 &

kill-proxies:                     ## Kill proxies (kills all kubectl processes)
	@pkill kubectl || true

kill-prometheus:                  ## Kill prometheus monitoring
	@$(HELM) uninstall -n $(MONITORING) prometheus
	@$(KUBECTL) delete --ignore-not-found crd prometheuses.monitoring.coreos.com
	@$(KUBECTL) delete --ignore-not-found crd prometheusrules.monitoring.coreos.com
	@$(KUBECTL) delete --ignore-not-found crd servicemonitors.monitoring.coreos.com
	@$(KUBECTL) delete --ignore-not-found crd podmonitors.monitoring.coreos.com
	@$(KUBECTL) delete --ignore-not-found crd alertmanagers.monitoring.coreos.com
	@$(KUBECTL) delete --ignore-not-found crd thanosrulers.monitoring.coreos.com
	@$(KUBECTL) delete --ignore-not-found crd probes.monitoring.coreos.com
	@$(KUBECTL) delete ns $(MONITORING)

kill-dashboard:
	@$(KUBECTL) delete -f $(DASHBOARD)
	@$(KUBECTL) delete -f deploy/dashboard/dashboard.admin-user.yaml -f deploy/dashboard/dashboard.admin-user-role.yaml

kill-studio:
	@$(KUBECTL) delete -f deploy/cassandra/studio.yaml
	@$(KUBECTL) delete ns $(STUDIO)

help:                             ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m 	%s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

cron-connector:                   ## Deploy Cron Connector
	$(info Deploying Cron Connector)
	$(KUBECTL) apply -f deploy/cron-connector
