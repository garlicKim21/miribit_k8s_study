#1 git clone으로 실습용 코드를 다운로드 합니다.
git clone https://github.com/garlicKim21/miribit_k8s_study.git

#2 실습용 코드가 있는 디렉토리로 이동합니다.
cd miribit_k8s_study/01-kubeadm

#3 k8s-node.txt 파일을 확인합니다.
cat k8s-nodes.txt

#4 k8s-node.txt 파일을 수정합니다. 사용자 번호에 맞게 반드시 IP 주소와 호스트명을 수정하여 사용해야 합니다!
vim k8s-nodes.txt

#5 k8s-node.txt 파일을 저장합니다.
:wq

#6 k8s-prepared-node.sh를 확인합니다.
cat k8s-prepare-node.sh

#7 모든 노드에 k8s-nodes.txt 파일을 전송합니다.
scp k8s-nodes.txt root@192.168.104.82:/root/
scp k8s-nodes.txt root@192.168.104.83:/root/
scp k8s-nodes.txt root@192.168.104.84:/root/
scp k8s-nodes.txt root@192.168.104.85:/root/
scp k8s-nodes.txt root@192.168.104.86:/root/

#8 모든 노드에 k8s-prepare-node.sh 파일을 전송합니다.
scp k8s-prepare-node.sh root@192.168.104.82:/root/
scp k8s-prepare-node.sh root@192.168.104.83:/root/
scp k8s-prepare-node.sh root@192.168.104.84:/root/
scp k8s-prepare-node.sh root@192.168.104.85:/root/
scp k8s-prepare-node.sh root@192.168.104.86:/root/

#9 모든 노드에서 k8s-prepare-node.sh 파일을 실행합니다.
bash k8s-prepare-node.sh
ssh root@192.168.104.82 "bash k8s-prepare-node.sh"
ssh root@192.168.104.83 "bash k8s-prepare-node.sh"
ssh root@192.168.104.84 "bash k8s-prepare-node.sh"
ssh root@192.168.104.85 "bash k8s-prepare-node.sh"
ssh root@192.168.104.86 "bash k8s-prepare-node.sh"

#10 kubeadm-init-config.yaml 파일을 확인합니다.
cat kubeadm-init-config.yaml

#11 kubeadm-init-config.yaml 파일을 수정합니다. 사용자 번호에 맞게 반드시 IP 주소와 호스트명을 수정하여 사용해야 합니다!
vim kubeadm-init-config.yaml

#12 kubeadm-init-config.yaml 파일을 저장합니다.
:wq

#13 kubeadm init 명령어를 실행합니다.
kubeadm init --config=kubeadm-init-config.yaml --upload-certs

#14 출력 내용을 확인합니다.
# ========================================
# Your Kubernetes control-plane has initialized successfully!

# To start using your cluster, you need to run the following as a regular user:

#   mkdir -p $HOME/.kube
#   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#   sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Alternatively, if you are the root user, you can run:

#   export KUBECONFIG=/etc/kubernetes/admin.conf

# You should now deploy a pod network to the cluster.
# Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#   https://kubernetes.io/docs/concepts/cluster-administration/addons/

# You can now join any number of control-plane nodes running the following command on each as root:

#   kubeadm join 192.168.104.80:6443 --token 77r3ls.m4zfvcy5b57rme5v \
# 	--discovery-token-ca-cert-hash sha256:859040d452646d7e7482f004b7b9eabda163231c173620e424cc6f08e752e8b3 \
# 	--control-plane --certificate-key 19ac2693f5a9b4be9e3cefde3fdab862cba01734f4fdb8ab44cfef7ea557b800

# Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
# As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
# "kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

# Then you can join any number of worker nodes by running the following on each as root:

# kubeadm join 192.168.104.80:6443 --token 77r3ls.m4zfvcy5b57rme5v \
# 	--discovery-token-ca-cert-hash sha256:859040d452646d7e7482f004b7b9eabda163231c173620e424cc6f08e752e8b3
# ========================================

#15 ctrl-2, ctrl-3에 ssh로 접근하여 controlplane join 명령어를 실행합니다.
ssh root@192.168.104.82
ssh root@192.168.104.83

#16 ctrl-2, ctrl-3에서 kubeadm join 명령어를 실행합니다.
# ========================================
# 실제 토큰과 ca-cert-hash는 초기화 시 받은 값을 사용합니다.
# kubeadm join 192.168.104.80:6443 --token 77r3ls.m4zfvcy5b57rme5v \
# 	--discovery-token-ca-cert-hash sha256:859040d452646d7e7482f004b7b9eabda163231c173620e424cc6f08e752e8b3
# ========================================

#17 wkr-1, wkr-2, wkr-3에서 kubeadm join 명령어를 실행합니다.
# ========================================
# 실제 토큰과 ca-cert-hash는 초기화 시 받은 값을 사용합니다.
# kubeadm join 192.168.104.80:6443 --token 77r3ls.m4zfvcy5b57rme5v \
# 	--discovery-token-ca-cert-hash sha256:859040d452646d7e7482f004b7b9eabda163231c173620e424cc6f08e752e8b3
# ========================================

#18 ctrl-1에 kubeconfig 파일을 설정합니다.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#19 kubectl get nodes 명령어를 실행하여 클러스터 상태를 확인합니다.
kubectl get nodes

#20 cilium cli를 설치합니다.
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

#21 cilium install 명령어를 실행하여 cilium을 설치합니다.
cilium install --version 1.18.4

#22 kube-system 네임스페이스에 pod 상태를 확인합니다.
watch kubectl get pods -n kube-system

#23 cilium status 명령어를 실행하여 cilium 상태를 확인합니다.
cilium status --wait

#24 kubectl get nodes 명령어를 실행하여 클러스터 상태를 확인합니다.
kubectl get nodes

#25 etcd pod 상태를 확인합니다.
kubectl get pods -n kube-system | grep etcd

#26 etcdctl을 모든 control plane 노드에 설치합니다.
# Kubernetes 1.34.1과 호환되는 etcd 버전을 사용합니다 (일반적으로 3.5.x)
ETCD_VERSION="3.5.15"

# ctrl-1에 etcdctl 설치 (아키텍처 자동 감지)
ARCH=\$(uname -m); if [ \"\$ARCH\" = \"aarch64\" ]; then ETCD_ARCH=\"arm64\"; else ETCD_ARCH=\"amd64\"; fi; cd /tmp && curl -L https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-\${ETCD_ARCH}.tar.gz -o etcd-v${ETCD_VERSION}-linux-\${ETCD_ARCH}.tar.gz && tar xzf etcd-v${ETCD_VERSION}-linux-\${ETCD_ARCH}.tar.gz && cp etcd-v${ETCD_VERSION}-linux-\${ETCD_ARCH}/etcdctl /usr/local/bin/ && chmod +x /usr/local/bin/etcdctl && rm -rf etcd-v${ETCD_VERSION}-linux-\${ETCD_ARCH}*

#27 etcd 클러스터 멤버를 확인합니다.
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key member list -w table

#28 etcd 클러스터의 리더를 확인합니다.
ETCDCTL_API=3 etcdctl --endpoints=https://192.168.104.81:2379,https://192.168.104.82:2379,https://192.168.104.83:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status -w table