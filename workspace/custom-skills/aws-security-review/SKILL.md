
# AWS Security Review

A structured audit of an AWS account or organization.

## 1. IAM Deep Dive

- Enumerate users, roles, policies (identity + resource + permission boundaries)
- Hunt privilege escalation paths: `iam:CreatePolicyVersion`, `iam:PassRole` + `ec2:RunInstances`/lambda creation, `sts:AssumeRole` chains, `iam:SetDefaultPolicyVersion`
- Wildcard actions/resources on trust boundaries; `NotAction` with `Effect: Allow` traps
- Unused credentials, access keys older than 90 days, no rotation
- Check trust policies: roles assumable by `*` or by external account IDs

### Tools
- `scoutSuite`, `prowler`, `pmapper` (privilege escalation graph), `cloudsplaining` (least-privilege diffs)

## 2. Exposure Review

- S3: public buckets/block public access at account level; ACLs vs bucket policy conflicts
- EBS/RDS/redshift snapshots: shared or public
- Load balancers/security groups: `0.0.0.0/0` on management ports (22/3389), database ports exposed
- API Gateway, Lambda function URLs, Elasticsearch/OpenSearch domains with open access policies

## 3. Encryption and Data

- Default encryption on S3/EBS/RDS; KMS key policies scoped correctly
- Secrets Manager vs hardcoded values in env vars committed to IaC
- CloudTrail: multi-region, log file validation, no public bucket; GuardDuty enabled

## 4. Network

- VPC flow logs on; NAT gateway vs IGW placement for private subnets
- Peering/transit gateway routes leaking ranges
- Public subnets hosting workloads that should be private

## 5. Workload Identity

- EC2 instance profiles over long-lived keys; EKS IRSA / pod identity
- Tasks/containers without privileged modes; metadata service v2 enforced

## Output

Ranked findings: exposure (public data/ports), privilege escalation chains (with `pmapper`-style path evidence), logging gaps, and remediation mapped to specific policy/resource ARNs.
