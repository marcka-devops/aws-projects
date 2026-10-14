# Golden AMI

Builds the web server image (Amazon Linux 2023, Apache, PHP, CodeDeploy agent, CloudWatch agent) in us-east-1 and copies it to us-west-2. This covers the EC2 case study's "manage web servers using an AMI" and "replicate to Oregon".

```bash
packer init packer
packer validate packer
packer build packer
```

CI runs the same build from the **Golden AMI** workflow.

To use the image, set `golden_ami_name = "marck-enterprise-web"` in `infra/stacks/50-compute` and apply. Both fleets roll onto the newest matching AMI through an instance refresh.
