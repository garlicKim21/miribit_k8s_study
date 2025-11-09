# Kubernetes 클러스터 구축 교육 자료

Miribit 개발자 및 SM 직무자를 위한 Kubernetes 초급 강의 자료입니다.

## 📚 강의 목표

이 강의는 총 4주에 걸쳐 Kubernetes 클러스터를 직접 구축하고 운영하는 방법을 학습하는 것을 목표로 합니다.

### 01주차: Kubernetes 기초
- 컨테이너와 Kubernetes
- Kubernetes 컴포넌트에 대한 이해
- Kubernetes 배포 방식 소개

### 02주차: Kubeadm과 Kubespray 비교
- Kubeadm을 활용한 Kubernetes 클러스터 구성
- Kubespray 구조 파악
- Kubespray를 활용한 Kubernetes 클러스터 구성

### 03주차: Container Runtime
- Container Runtime과 Kubernetes
- Containerd 핸들링 하기

### 04주차: Kubernetes Network
- Container Network Interface 개요
- Cilium 이해
- Kubernetes Service Type / CoreDNS

> **참고**: 이 레포지토리는 강의 진행에 맞춰 지속적으로 업데이트됩니다.

## 🏗️ 프로젝트 구조

```
miribit_k8s_study/
├── 01-kubeadm/              # kubeadm을 사용한 수동 클러스터 구성
│   ├── k8s-prepare-node.sh  # 노드 준비 스크립트 (Rocky Linux 10)
│   ├── k8s-nodes.txt        # 노드 IP 및 호스트명 설정 파일
│   └── kubeadm-init-config.yaml  # kubeadm 초기화 설정 파일
│
├── 02-kubespray/            # kubespray를 사용한 자동화 배포
│   ├── inventory.ini       # Ansible 인벤토리 파일
│   └── custom.yml          # kubespray 커스텀 설정 파일
│
└── README.md               # 이 파일
```

## 🖥️ 환경 요구사항

### 하드웨어
- **컨트롤 플레인 노드**: 3대 (고가용성 구성)
- **워커 노드**: 3대
- 각 노드 최소 사양: 2 CPU, 4GB RAM, 20GB 디스크

### 소프트웨어
- **OS**: Rocky Linux 10
- **컨테이너 런타임**: containerd 2.2.0 (바이너리 설치)
- **Kubernetes**: 1.34.1
- **CNI**: Cilium
- **로드밸런서**: HAProxy (VIP: 192.168.104.80:6443)

### 네트워크
- 모든 노드 간 네트워크 통신 가능
- HAProxy VIP를 통한 API 서버 접근 가능

## 📖 사용 방법

### 1단계: kubeadm을 사용한 수동 클러스터 구성

#### 1.1 노드 준비

모든 노드에서 다음 스크립트를 실행합니다:

```bash
# k8s-nodes.txt 파일을 각 노드의 IP와 호스트명에 맞게 수정
vi 01-kubeadm/k8s-nodes.txt

# 노드 준비 스크립트 실행 (root 권한 필요)
sudo bash 01-kubeadm/k8s-prepare-node.sh
```

**스크립트가 수행하는 작업:**
- Swap 비활성화
- 커널 모듈 로드 (overlay, br_netfilter)
- sysctl 파라미터 설정
- containerd 2.2.0 바이너리 설치
- runc 바이너리 설치
- CNI 플러그인 바이너리 설치
- Kubernetes 도구 설치 (kubelet, kubeadm, kubectl)

#### 1.2 첫 번째 컨트롤 플레인 노드 초기화

```bash
# kubeadm-init-config.yaml 파일 확인 및 수정
vi 01-kubeadm/kubeadm-init-config.yaml

# 클러스터 초기화
sudo kubeadm init --config=01-kubeadm/kubeadm-init-config.yaml --upload-certs
```

**중요:** 초기화 완료 후 출력되는 다음 정보를 기록하세요:
- 부트스트랩 토큰 (`token`)
- 인증서 키 (`certificate-key`)
- CA 인증서 해시 (`ca-cert-hash`)

#### 1.3 kubectl 설정

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 1.4 추가 컨트롤 플레인 노드 조인

```bash
# 각 추가 컨트롤 플레인 노드에서 실행
# kubeadm-join-controlplane-config.yaml 파일 수정 필요:
# - advertiseAddress: 해당 노드의 IP
# - name: 해당 노드의 호스트명
# - token, certificateKey, caCertHashes: 초기화 시 받은 값 입력

sudo kubeadm join --config=kubeadm-join-controlplane-config.yaml --control-plane
```

#### 1.5 워커 노드 조인

```bash
# 각 워커 노드에서 실행
# kubeadm-join-worker-config.yaml 파일 수정 필요:
# - name: 해당 노드의 호스트명
# - token, caCertHashes: 초기화 시 받은 값 입력

sudo kubeadm join --config=kubeadm-join-worker-config.yaml
```

### 2단계: kubespray를 사용한 자동화 배포

#### 2.1 인벤토리 파일 설정

```bash
# inventory.ini 파일 수정
vi 02-kubespray/inventory.ini

# 주석(;)을 제거하고, 사용자 환경에 맞게 호스트명과 IP 주소 수정
# - ansible_host: Ansible이 SSH로 연결할 IP 주소
# - ip: Kubernetes 서비스가 바인딩할 IP 주소
```

#### 2.2 커스텀 설정 확인

```bash
# custom.yml 파일 확인 및 필요시 수정
vi 02-kubespray/custom.yml
```

**주요 설정:**
- `kube_network_plugin: cilium` - CNI 플러그인
- `loadbalancer_apiserver_type: nginx` - 로드밸런서 타입
- `helm_enabled: true` - Helm 설치
- `metrics_server_enabled: true` - Metrics Server 설치

#### 2.3 클러스터 배포

```bash
# kubespray 디렉토리로 이동
cd kubespray

# 클러스터 설치
ansible-playbook -i ../inventory.ini cluster.yml -e @../custom.yml -b -v
```

**다른 플레이북:**
- 클러스터 업그레이드: `ansible-playbook -i ../inventory.ini upgrade-cluster.yml -e @../custom.yml`
- 클러스터 제거: `ansible-playbook -i ../inventory.ini reset.yml`
- 노드 추가: `ansible-playbook -i ../inventory.ini scale.yml -e @../custom.yml`

## 🔧 주요 설정 파일 설명

### kubeadm-init-config.yaml
- **용도**: 첫 번째 컨트롤 플레인 노드 초기화 설정
- **주요 설정**:
  - `controlPlaneEndpoint`: HAProxy VIP (192.168.104.80:6443)
  - `certSANs`: 인증서에 포함될 IP 및 호스트명 목록
  - `kubernetesVersion`: v1.34.1
  - `podSubnet`: 10.244.0.0/16
  - `serviceSubnet`: 10.96.0.0/12

### k8s-prepare-node.sh
- **용도**: 모든 노드의 사전 준비 작업 자동화
- **설치 항목**:
  - containerd 2.2.0 (바이너리)
  - runc 1.2.0 (바이너리)
  - CNI 플러그인 1.5.1 (바이너리)
  - Kubernetes 도구 (kubelet, kubeadm, kubectl)

### inventory.ini
- **용도**: kubespray에서 사용하는 노드 정보
- **주요 섹션**:
  - `[all]`: 모든 노드 목록
  - `[kube_control_plane]`: 컨트롤 플레인 노드
  - `[etcd]`: etcd 노드 (stacked 구성)
  - `[kube_node]`: 워커 노드

### custom.yml
- **용도**: kubespray 기본 설정 오버라이드
- **주요 설정**: 네트워크 플러그인, 로드밸런서 타입, 애드온 등

## ⚠️ 주의사항

1. **HAProxy 설정**: kubeadm init 전에 HAProxy 백엔드 설정이 올바른지 확인하세요. 잘못된 설정은 인증서 생성에 영향을 줍니다.

2. **네트워크 설정**: 모든 노드의 `/etc/hosts` 파일이 올바르게 설정되어 있어야 합니다.

3. **방화벽**: 필요한 포트가 열려있는지 확인하세요:
   - 6443: Kubernetes API 서버
   - 2379-2380: etcd
   - 10250-10259: kubelet, kube-scheduler, kube-controller-manager

4. **Swap**: Kubernetes는 swap을 비활성화해야 합니다. 스크립트에서 자동으로 처리합니다.

## 📝 학습 내용

이 강의를 통해 다음을 학습할 수 있습니다:

- Kubernetes 클러스터의 구조와 컴포넌트 이해
- kubeadm을 사용한 수동 클러스터 구성
- containerd 컨테이너 런타임 설정
- CNI 플러그인 설치 및 구성
- 고가용성 컨트롤 플레인 구성
- kubespray를 사용한 자동화 배포
- Ansible을 활용한 인프라 자동화

## 🔗 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [kubeadm 공식 문서](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [kubespray 공식 문서](https://kubespray.io/)
- [containerd 공식 문서](https://containerd.io/)

## 📄 라이선스

이 교육 자료는 Miribit 내부 교육용으로 제작되었습니다.

## 👥 기여자

- 강의 자료 작성 및 관리: 김현태 책임

