#!/bin/bash

# aws cli 버전 업그레이드
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
export PATH=/usr/local/bin:$PATH
source ~/.bash_profile

# aws cli 버전 확인
aws --version

# kubectl 명령어 설치 & 확인 
sudo curl -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
kubectl version --client=true --short=true

# jq 설치하기
sudo yum install -y jq

# bash-completion 설치하기 
sudo yum install -y bash-completion

# eksctl 명령어 설치하기 
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin
eksctl version

# 변수 설정 
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}

# 계정 ID 환경변수 설정 
export ACCOUNT_ID=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId')
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile


# Loadbalancer iam policy
curl -O iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

# create iam policy 
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# create service account
eksctl create iamserviceaccount \
    --cluster eks-interface \
    --namespace kube-system \
    --name aws-load-balancer-controller \
    --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve

# Certmanager 
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml

# Loadbalancer controller yaml
wget https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.4/v2_4_4_full.yaml

# 클러스터 파일에 cluster-name 편집 

# ServiceAccount 부분 삭제 

kubectl apply -f v2_4_4_full.yaml

kubectl get deployment -n kube-system aws-load-balancer-controller

# aws-load-balancer-controller 로그 확인하기 
kubectl logs -n kube-system $(kubectl get po -n kube-system | egrep -o "aws-load-balancer[a-zA-Z0-9-]+")

ALBPOD=$(kubectl get pod -n kube-system | egrep -o "aws-load-balancer[a-zA-Z0-9-]+")

kubectl describe pod -n kube-system ${ALBPOD}

---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: eks-demo # 생성할 EKS 클러스터명
  region: ap-northeast-2 # 클러스터를 생성할 리전
  version: "1.23"

vpc:
  cidr: "10.0.0.0/16" # 클러스터에서 사용할 VPC의 CIDR
  nat:
    gateway: HighlyAvailable

managedNodeGroups:
  - name: node-group # 클러스터의 노드 그룹명
    instanceType: t3.small # 클러스터 워커 노드의 인스턴스 타입
    desiredCapacity: 1 # 클러스터 워커 노드의 갯수
    volumeSize: 20  # 클러스터 워커 노드의 EBS 용량 (단위: GiB)
    privateNetworking: true
    ssh:
      enableSsm: true
    iam:
      withAddonPolicies:
        imageBuilder: true # Amazon ECR에 대한 권한 추가
        albIngress: true  # albIngress에 대한 권한 추가
        cloudWatch: true # cloudWatch에 대한 권한 추가
        autoScaler: true # auto scaling에 대한 권한 추가
        ebs: true # EBS CSI Driver에 대한 권한 추가

cloudWatch:
  clusterLogging:
    enableTypes: ["*"]

iam:
  withOIDC: true
