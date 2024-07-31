# diy_dyndns
Use APIs to update name server records without using for-pay DNS update services

GoDaddy disabled their API update service in May 2024 except for accounts that pay for extra account management features or have 50 or more domains registered. Thus will begin a search and comparison for free and low-cost domain registars or DNS management sites/utilities.

While working on a Udemy class for Terraform/Ansible/Prometheus/Grafana, we set up Jenkins using a Cloud9 development environment and I wanted a hostname that would resolve externally and could be updated automatically, to see if I can avoid using an Elastic IP for Jenkins. I set up a dynu.org domain and figured out the Terraform necessary to dynamically update it.

This will check for extant (sub)domains, compare any to a configurable "dns_name" (var.dns_name defaults to "subdomain" as an example but can be overridden in terraform.tfvars or on the command line), and choose whether to add or update your dynu account.

NOTE: dynu.com currently has a limit of 4 nodes/subdomains per free account, and I do not do any error checking to verify if that has been exceeded. Watch the output in case you use it heavily.

NOTE 2: There is no provider currently available for dynu.com, so I use Terraform data sources to interact with dynu.com's API (v2). Terraform expects data sources to be read-only, but because this is an API, please note that a "terraform plan" will be functionally equivalent to a "terraform apply -auto-approve".

