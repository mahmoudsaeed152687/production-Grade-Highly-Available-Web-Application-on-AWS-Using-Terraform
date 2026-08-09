# AWS Scalable Web Application with Terraform

A production-oriented, highly available and scalable web application infrastructure built on AWS using Terraform.

The architecture is deployed across two Availability Zones and follows AWS best practices for networking, security, scalability, monitoring, and secure instance access.

---

## Architecture

![AWS Scalable Web Application Architecture](docs/architecture.png)

### Request Flow

```text
                        Internet
                           │
                           ▼
                    ┌──────────────┐
                    │  CloudFront  │
                    │ CDN + Caching│
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │     WAF      │
                    │ Web Protection│
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │     ALB      │
                    │ Load Balancer│
                    └──────┬───────┘
                           │
                    ┌──────┴──────┐
                    ▼             ▼
               ┌─────────┐   ┌─────────┐
               │  EC2-A  │   │  EC2-B  │
               │ Private │   │ Private │
               │ Subnet  │   │ Subnet  │
               └────┬────┘   └────┬────┘
                    │             │
                    └──────┬──────┘
                           ▼
                    ┌──────────────┐
                    │ RDS PostgreSQL│
                    │   Multi-AZ   │
                    └──────────────┘


       Private EC2 ──► NAT Gateway ──► Internet Gateway
```

---

## Project Overview

This project demonstrates how to deploy a scalable EC2-based web application on AWS using Infrastructure as Code with Terraform.

The infrastructure is deployed across two Availability Zones in `us-west-2` and separates public, application, and database workloads into dedicated subnets.

The application is designed to provide:

- High availability
- Horizontal scalability
- Private application and database workloads
- Secure network segmentation
- Load balancing
- Static asset caching
- Web application firewall protection
- Centralized monitoring and alerting
- Secure EC2 access without SSH

---

## AWS Services

| Service | Purpose |
|---|---|
| Amazon VPC | Isolated network environment |
| Public Subnets | ALB and NAT Gateway resources |
| Private App Subnets | EC2 application instances |
| Private DB Subnets | RDS database |
| Internet Gateway | Internet connectivity for public resources |
| NAT Gateway | Outbound internet access for private instances |
| Security Groups | Stateful network access control |
| Application Load Balancer | Traffic distribution across EC2 instances |
| Auto Scaling Group | Automatic EC2 scaling and high availability |
| Launch Template | Standardized EC2 configuration |
| Amazon EC2 | Application compute layer |
| Amazon RDS | PostgreSQL database |
| RDS Multi-AZ | Database high availability |
| AWS WAF | Web application protection |
| Amazon CloudFront | CDN and static asset caching |
| AWS Systems Manager | Secure instance access |
| Amazon CloudWatch | Monitoring and alarms |
| Amazon SNS | Alert notifications |

---

## Network Architecture

The VPC is deployed across two Availability Zones:

```text
VPC
│
├── Availability Zone A
│   ├── Public Subnet
│   ├── Private App Subnet
│   └── Private DB Subnet
│
└── Availability Zone B
    ├── Public Subnet
    ├── Private App Subnet
    └── Private DB Subnet
```

### Public Subnets

Public subnets contain resources that require direct internet connectivity, such as:

- Application Load Balancer
- NAT Gateway

Public traffic is routed through the Internet Gateway.

### Private Application Subnets

EC2 instances are deployed in private subnets with no public IP addresses.

Outbound internet traffic is routed through:

```text
EC2
 ↓
NAT Gateway
 ↓
Internet Gateway
 ↓
Internet
```

### Private Database Subnets

RDS is deployed in dedicated private database subnets across multiple Availability Zones.

The database is not directly accessible from the internet.

---

## Security Architecture

Security is implemented using layered network controls.

### Security Groups

Traffic is restricted between application layers:

```text
Internet
   │
   │ HTTP :80
   ▼
ALB Security Group
   │
   │ HTTP :80
   ▼
EC2 Security Group
   │
   │ PostgreSQL :5432
   ▼
RDS Security Group
```

### Access Rules

- ALB accepts HTTP traffic from the internet.
- EC2 accepts HTTP traffic only from the ALB Security Group.
- RDS accepts PostgreSQL traffic only from the EC2 Security Group.
- EC2 instances do not have public IP addresses.
- Database instances are isolated in private DB subnets.

---

## Load Balancing & Auto Scaling

The application uses an Application Load Balancer in front of an Auto Scaling Group.

```text
                    ALB
                     │
             ┌───────┴───────┐
             ▼               ▼
          EC2-A            EC2-B
             │               │
             └───────┬───────┘
                     ▼
                    RDS
```

The Auto Scaling Group provides:

- Minimum and maximum capacity
- Multi-AZ deployment
- Automatic instance replacement
- Target tracking scaling
- Integration with the ALB Target Group

---

## Database

The application uses Amazon RDS PostgreSQL.

The database layer is designed for high availability using Multi-AZ deployment.

Key characteristics:

- PostgreSQL
- Private DB subnets
- Multi-AZ
- Security Group restricted to application instances
- Automated backups
- No public accessibility

---

## CloudFront

Amazon CloudFront is deployed in front of the Application Load Balancer.

```text
Client
  │
  ▼
CloudFront
  │
  ▼
ALB
  │
  ▼
EC2
```

Dynamic application traffic is not cached by default.

Static assets under:

```text
/static/*
```

are configured for caching to reduce latency and decrease requests reaching the application servers.

---

## AWS WAF

AWS WAF is associated with the Application Load Balancer.

Managed AWS rule groups are used to provide protection against common malicious web requests.

Configured managed rule groups include:

- AWS Managed Rules Common Rule Set
- AWS Managed Rules Known Bad Inputs Rule Set

This provides an additional security layer between incoming web traffic and the application infrastructure.

---

## Secure EC2 Access

EC2 instances are accessed using AWS Systems Manager Session Manager.

No SSH access is required.

```text
Administrator
     │
     ▼
Systems Manager
     │
     ▼
Private EC2
```

This allows secure administrative access without:

- Public IP addresses
- SSH port 22
- Bastion hosts

---

## Monitoring & Alerting

Amazon CloudWatch is used to monitor infrastructure health and application metrics.

Configured monitoring includes:

- EC2 / ASG CPU utilization
- ALB unhealthy target count
- WAF blocked requests
- ALB request count

CloudWatch alarms send notifications through Amazon SNS.

```text
CloudWatch
    │
    ▼
Alarm
    │
    ▼
SNS
    │
    ▼
Email Notification
```

---

## Infrastructure as Code

The entire infrastructure is managed using Terraform.

### Terraform Structure

```text
.
├── provider.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
│
├── network.tf
├── security.tf
├── compute.tf
├── alb.tf
├── database.tf
├── monitoring.tf
└── waf-cloudfront.tf
```

### File Responsibilities

| File | Responsibility |
|---|---|
| `provider.tf` | AWS providers and regions |
| `variables.tf` | Input variables |
| `outputs.tf` | Terraform outputs |
| `network.tf` | VPC, subnets, routing, NAT, IGW |
| `security.tf` | Security Groups |
| `compute.tf` | EC2, Launch Template, ASG |
| `alb.tf` | ALB, Target Group, Listener |
| `database.tf` | RDS and DB subnet configuration |
| `monitoring.tf` | CloudWatch and SNS |
| `waf-cloudfront.tf` | WAF and CloudFront |
| `terraform.tfvars` | Environment-specific values |

---

## Deployment

### Prerequisites

Make sure you have:

- AWS account
- AWS CLI
- Terraform
- Configured AWS credentials

Verify AWS credentials:

```bash
aws sts get-caller-identity
```

Verify Terraform:

```bash
terraform version
```

### Initialize Terraform

```bash
terraform init
```

### Format Configuration

```bash
terraform fmt -recursive
```

### Validate Configuration

```bash
terraform validate
```

### Review Infrastructure Changes

```bash
terraform plan
```

### Deploy Infrastructure

```bash
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

> `terraform destroy` removes the infrastructure created by this project. Use it carefully.

---

## Important Outputs

After deployment, useful outputs can be displayed with:

```bash
terraform output
```

For example:

```bash
terraform output cloudfront_domain_name
```

The CloudFront domain can be used to access the application without requiring a custom domain.

---

## Validation

The infrastructure was validated through the following checks:

- Terraform configuration validation
- VPC and subnet verification
- Multi-AZ deployment verification
- Private EC2 connectivity
- ALB target health checks
- EC2 to RDS PostgreSQL connectivity
- Systems Manager Session Manager access
- Auto Scaling configuration
- CloudFront origin connectivity
- WAF configuration
- CloudWatch monitoring
- SNS notifications

---

## Project Requirements

- [x] Multi-AZ VPC architecture
- [x] Public and private subnets
- [x] NAT Gateway
- [x] Internet Gateway
- [x] Security Groups
- [x] EC2-based application
- [x] Launch Template
- [x] Auto Scaling Group
- [x] Target Tracking scaling
- [x] Application Load Balancer
- [x] ALB Target Group
- [x] AWS WAF
- [x] CloudFront
- [x] RDS PostgreSQL
- [x] RDS Multi-AZ
- [x] Systems Manager Session Manager
- [x] CloudWatch monitoring
- [x] SNS notifications
- [ ] Route 53 custom domain

### Route 53

Route 53 was intentionally omitted because this project does not use a custom domain.

CloudFront's default distribution domain is used for application access.

---

## Lessons Learned

This project provided hands-on experience with:

- AWS VPC design
- Multi-AZ architecture
- Public vs private subnet design
- NAT Gateway routing
- Security Group-based network segmentation
- EC2 Auto Scaling
- Application Load Balancing
- RDS Multi-AZ architecture
- AWS WAF
- CloudFront caching
- Systems Manager Session Manager
- CloudWatch monitoring
- SNS alerting
- Infrastructure as Code with Terraform

---

## Future Improvements

Potential future improvements include:

- HTTPS with ACM certificates
- Custom domain with Route 53
- CloudFront-scoped WAF
- HTTPS between CloudFront and ALB
- Remote Terraform state using S3
- Terraform state locking
- Separate Terraform environments
- Reusable Terraform modules
- CI/CD pipeline using GitHub Actions
- Application secrets stored in AWS Secrets Manager
- Centralized logging
- Additional CloudWatch alarms
- HTTPS-only ALB listener

---

## Technologies

```text
AWS
Terraform
HCL
Amazon VPC
Amazon EC2
Auto Scaling
Application Load Balancer
Amazon RDS
AWS WAF
Amazon CloudFront
AWS Systems Manager
Amazon CloudWatch
Amazon SNS
PostgreSQL
```

---

## Author

**Mahmoud**

Built as a hands-on AWS and Terraform infrastructure project focused on production-oriented cloud architecture and Infrastructure as Code.
AI was used as a learning and troubleshooting tool, not as a replacement for understanding, implementing, and validating the infrastructure.