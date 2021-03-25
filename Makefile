#!/usr/bin/make

SHELL ?= bash

include .env

.PHONY: up
up: create-cluster

.PHONY: install-docker
install-docker:
	sudo apt-get update
	sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu `lsb_release -cs` stable"
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io
	sudo usermod -aG docker `id -un`

	@tput setaf 3; echo -e "\nLogout and login to reload group rights!\n"; tput sgr0

.PHONY: install-kubectl
install-kubectl:
	# Download and install kubectl
	curl -Lo /tmp/kind https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl
	chmod +x /tmp/kubectl
	sudo mv /tmp/kubectl /usr/local/bin

	# Install kubectl completion
	mkdir -p ~/.kube
	echo >>~/.bashrc
	echo 'source <(kubectl completion bash)' >>~/.bashrc

	@tput setaf 3; echo -e "\nStart a new shell to load kubectl completion!\n"; tput sgr0

.PHONY: install-kind
install-kind:
	# Download and install kind
	curl -Lo /tmp/kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
	chmod +x /tmp/kind
	sudo mv /tmp/kind /usr/local/bin

	# Install kind completion
	echo >>~/.bashrc
	echo 'source <(kind completion bash)' >>~/.bashrc

	@tput setaf 3; echo -e "\nStart a new shell to load kind completion!\n"; tput sgr0

.PHONY: install-helm
install-helm:
	# Download and install helm
	curl -sfL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
	helm repo add stable https://charts.helm.sh/stable
	helm repo update

.PHONY: install-kustomize
install-kustomize:
	# Download and install kustomize
	curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz -o kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && tar -zxvf kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && chmod +x kustomize
	sudo mv kustomize /usr/local/bin/kustomize

.PHONY: create-cluster
create-cluster:
	@tput setaf 6; echo -e "\nmake $@\n"; tput sgr0

	./scripts/kind-with-registry.sh

	kubectl cluster-info --context kind-${KIND_CLUSTER_NAME}

	kubectl wait --for=condition=Ready --timeout=${KIND_WAIT} -A pod --all \
			|| echo 'TIMEOUT' >&2

install-ingress-nginx:
	kubectl create namespace ingress-nginx
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx -w

install-chartmuseum:
	helm repo add stable https://charts.helm.sh/stable
	helm repo update
	helm install chartmuseum --namespace default stable/chartmuseum --version 2.7.1 --set env.open.DISABLE_API=false --set ingress.enabled=true --set ingress.hosts[0].path=/
	kubectl wait --for=condition=available deployment chartmuseum-chartmuseum --timeout=120s

.PHONY: delete-cluster
delete-cluster:
	@tput setaf 6; echo -e "\nmake $@\n"; tput sgr0
	if [ $$(kind get clusters | grep ${KIND_CLUSTER_NAME}) ]; then ./scripts/teardown-kind-with-registry.sh fi

.PHONY: down
down: delete-cluster
