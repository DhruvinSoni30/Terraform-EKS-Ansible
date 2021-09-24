# How to deploy the Kubernetes application to AWS EKS using Terraform and Ansible?

### What is AWS EKS?

Amazon Elastic Kubernetes Service (Amazon EKS) is a managed Kubernetes service provided by AWS. Through AWS EKS we can run Kubernetes without installing and operating a Kubernetes control plane or worker nodes. AWS EKS helps you provide highly available and secure clusters and automates key tasks such as patching, node provisioning, and updates.

![1](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/1.png)

### What is Terraform?

Terraform is a free and open-source infrastructure as code (IAC) that can help to automate the deployment, configuration, and management of the remote servers. Terraform can manage both existing service providers and custom in-house solutions.

![2](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/2.png)

### What is Ansible?

Ansible is an open-source software provisioning, configuration management, and deployment tool. It runs on many Unix-like systems and can configure both Unix-like systems as well as Microsoft Windows. Ansible uses SSH protocol in order to configure the remote servers. Ansible follows the push-based mechanism to configure the remote servers.

![3](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/3.png)

This tutorial is divided into 2 parts.
* Create the Kubernetes cluster using Terraform
* Deploy the Kubernetes application using Ansible

![4](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/4.png)

**Prerequisites:**

* AWS Account
* Basic understanding of AWS, Terraform, Ansible & Kubernetes
* GitHub Account

# Part 1:- Terraform scripts for the Kubernetes cluster.

**Step 1:- Create `.tf` file for storing environment variables**

* Create `vars.tf` file and add below content in it
  ```
  variable "access_key" {
    default = "<Your-AWS-Access-Key>"
  }
  variable "secret_key" {
    default = "<Your-AWS-Secret-Key>"
  }
  ```
 
**Step 2:- Create `.tf` file for AWS Configuration**

* Create `main.tf` file and add below content in it
  ```
  provider "aws" {
    region = "us-east-1"
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
  }
  data "aws_availability_zones" "azs" {
    state = "available"
  }
  ```
* data `"aws_availability_zones"` `"azs"` will provide the list of availability zone for the us-east-1 region

**Step 3:- Create .tf file for AWS VPC**

* Create `vpc.tf` file for VPC and add below content in it

  ```
  variable "region" {
    default = "us-east-1"
  }
  data "aws_availability_zones" "available" {}
  locals {
    cluster_name = "EKS-Cluster"
  }
  module vpc {
    source = "terraform-aws-modules/vpc/aws"
    version = "3.2.0"
    name = "Demo-VPC"
    cidr = "10.0.0.0/16"
    azs = data.aws_availability_zones.available.names
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets =  ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    enable_nat_gateway = true
    single_nat_gateway = true
    enable_dns_hostname = true
  tags = {
    "Name" = "Demo-VPC"
  }
  public_subnet_tags = {
    "Name" = "Demo-Public-Subnet"
  }
  private_subnet_tags = {
    "Name" = "Demo-Private-Subnet"
  }
  }
  ```
* We are using the AWS VPC module for VPC creation
* The above code will create the AWS VPC of `10.0.0.0/16` CIDR range in `us-east-1` region
* The VPC will have 3 public and private subnets
* `data "aws_availability_zones"` `"azs"` will provide the list of availability zone for the `us-east-1` region
* I have enabled the NAT Gateway & DNS Hostname

**Step 4:- Create .tf file for AWS Security Group**

* Create `security.tf` file for AWS Security Group and add below content in it

  ```
  resource "aws_security_group" "worker_group_mgmt_one" {
    name_prefix = "worker_group_mgmt_one"
    vpc_id = module.vpc.vpc_id
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
    cidr_blocks = [
            "10.0.0.0/8"
        ]
    }
  }
  resource "aws_security_group" "worker_group_mgmt_two" {
    name_prefix = "worker_group_mgmt_two"
    vpc_id = module.vpc.vpc_id
 
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
    cidr_blocks = [
            "10.0.0.0/8"
        ]
    }
  }
  resource "aws_security_group" "all_worker_mgmt" {
    name_prefix = "all_worker_management"
    vpc_id = module.vpc.vpc_id
  ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
  cidr_blocks = [
            "10.0.0.0/8"
        ]
    }
  }
  ```
  
* We are creating 2 security groups for 2 worker node group
* We are allowing only 22 port for the SSH connection
* We are restricting the SSH access for `10.0.0.0/8` CIDR Block

**Step 5:- Create .tf file for the EKS Cluster**

* Create `eks.tf` file for VPC and add below content in it

  ```
  module "eks"{
    source = "terraform-aws-modules/eks/aws"
    version = "17.1.0"
    cluster_name = local.cluster_name
    cluster_version = "1.20"
    subnets = module.vpc.private_subnets
  tags = {
        Name = "Demo-EKS-Cluster"
    }
  vpc_id = module.vpc.vpc_id
    workers_group_defaults = {
        root_volume_type = "gp2"
    }
  workers_group = [
        {
            name = "Worker-Group-1"
            instance_type = "t2.micro"
            asg_desired_capacity = 2
            additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
        },
        {
            name = "Worker-Group-2"
            instance_type = "t2.micro"
            asg_desired_capacity = 1
            additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
        },
    ]
  }
  data "aws_eks_cluster" "cluster" {
    name = module.eks.cluster_id
  }
  data "aws_eks_cluster_auth" "cluster" {
    name = module.eks.cluster_id
  }
  ```
* For EKS Cluster creation we are using the terraform AWS EKS module
* The below code will create 2 worker groups with the desired capacity of 3 instances of type t2.micro
* We are attaching the recently created security group to both the worker node groups

  ```
  workers_group = [
        {
            name = "Worker-Group-1"
            instance_type = "t2.micro"
            asg_desired_capacity = 2
            additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
        },
        {
            name = "Worker-Group-2"
            instance_type = "t2.micro"
            asg_desired_capacity = 1
            additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
        },
    ]
  ```

**Step 6:- Create .tf file for terraform Kubernetes provider**

* Create `kubernetes.tf` file and add below content in it

  ```
  provider "kubernetes" {
    host = data.aws_eks_cluster.cluster.endpoint
    token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64encode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
  ```
  
* In the above code, we are using a recently created cluster as the host and authentication token as token
* We are using the cluster_ca_certificate for the CA certificate

**Step 7:- Create .tf file for outputs**

* Create `outputs.tf` file and add below content in it

  ```
  output "cluster_id" {
    value = module.eks.cluster_id
  }
  output "cluster_endpoint" {
    value = module.eks.cluster_endpoint
  }
  ```

* The above code will give output the name of our cluster and expose the endpoint of our cluster.

**Step 8:- Store our code to GitHub Repository**

* Now, we have completed all the terraform scrips so, let's store the code in the GitHub repository

![5](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/5.png)

**Step 9:- Initialize the working directory**

* Run `terraform init` command in the working directory. It will download all the necessary providers and all the modules

**Step 10:- Create a terraform plan**

* Run `terraform plan` command in the working directory. It will give the execution plan

  ```
  Plan: 50 to add, 0 to change, 0 to destroy.
  Changes to Outputs:
  + cluster_endpoint = (known after apply)
  + cluster_id       = (known after apply)
  ```
  
**Step 11:- Create the cluster on AWS**

* Run `terraform apply` command in the working directory. It will be going to create the Kubernetes cluster on AWS
* Terraform will create the below resources on AWS

* VPC
* Route Table
* IAM Role
* NAT Gateway
* Security Group
* Public & Private Subnets
* EKS Cluster

**Step 12:- Verify the resources on AWS**

* Navigate to your AWS account and verify the resources

1. EKS Cluster:
![6](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/6.png)
![7](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/7.png)

2. VPC & other resources:
![8](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/8.png)

3. Subnets:
![9](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/9.png)

5. Security Group:
![10](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/10.png)

7. IAM Role:
![11](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/11.png)

9. Auto Scaling Groups:
![12](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/12.png)

11. EC2 Instances:
![13](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/13.png)

* Now, our Kubernetes cluster is ready so, let's start creating code for our application.
* In the above, I am managing the underlying EKS worker group's EC2 instances. So, I can modify the instances as I want.

# Part 2:- Ansible play for Kubernetes application

**Step 1:- Create .yml file for Pod definition**

* In the below code, I have used `dhsoni-web` image i.e my portfolio website's image. You can choose any other image also.
  ```
  apiVersion: v1
  kind: Pod
  metadata:
    name: mywebsite-pod
    labels:
      app: mywebsite
  spec:
    containers:
      - name: mywebsite-container
        image: dhruvin30/dhsoniweb
  ```
  
 **Step 2:- Create .yml file for Service definition**
 
 * Create `.yml` file and add the below code to it. It will create service of type loadbalancer
 
   ```
   apiVersion: v1
   kind: Service
   metadata:
    name: mywebsite-svc
    labels:
      app: mywebsite-svc
   spec:
     ports:
     - port: 80
       protocol: TCP
     selector:
       app: mywebsite-svc
       type: LoadBalancer
   ```
   
**Step 3:- Create .yml file for the ansible play**

* Create `.yml` file and add the below code in it. It will create the Pod and Service for the Kubernetes application.

  ```
  ---
  - name: Deploy to K8s Cluster 
    hosts: all
    become: true
  tasks:
    - name: Deploy Pod
      shell: |
        kubectl apply -f pod.yml
  
    - name: Deploy Service
      shell: | 
        kubectl apply -f svc.yml
  ```
  
* Run the below command in order to configure the application
```
ansible-playbook <playbookname.yml>
```

* After completion of play, you can check out the application by vising `ec2-ip:80` on the web browser. You should see output like below.

![14](https://github.com/DhruvinSoni30/Terraform-EKS-Ansible/blob/main/14.png)

That's it now, you have learned how to create the AWS EKS cluster using Terraform & How to create a Kubernetes application using Ansible. You can now play with it and modify it accordingly.
