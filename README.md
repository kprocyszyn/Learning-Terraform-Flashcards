# Learning-Terraform-Flashcards
Repository created specifically to deploy a simple web app with Terraform.

The purpose of this repository is to document my learning of Terraform, with deploying the real code.

## Folders

- Config: Contains all configuration files required by applications
- Flashcards: Is the Python web app written with Flask that allows user to review, add and delete flashcards
- Terraform: Is the actual Terraform config that deploys the Flashcards app. In essence, it creates a Linux VM, allowed SSH and HTTP traffic to it, and installs dependencies required by Flashcards app. After a successful run, it returns the IP address of the VM - that can be accessed via web browser and SSH.

# How to deploy

## Prerequisites 

- Azure Subscription
- Terraform installed on your machine 

## Deployment steps

1. git clone https://github.com/kprocyszyn/Learning-Terraform-Flashcards.git

2. cd .\Learning-Terraform-Flashcards\Terraform\

3. Terraform Init

4. cp .\terraform.tfvars.blank terraform.tfvars 

5. Now we need to create a service Principal account as outlined here: https://docs.microsoft.com/en-us/azure/developer/terraform/getting-started-cloud-shell

- Login to Azure and lunch cloud shell
- Execute az account show | grep id
- Copy the subscription ID
- run az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<subscription_id>"
- Copy the output values as these are values needed by Terraform.

6. Edit Terraform.tfvars file, and fill it with values from the Azure:
- appId = arm_principal
- password = arm_password
- tenant = tenant_id
- arm_subscription_id = subscription_id

and username and password you'd like to use for VM

7. Save the file
8. Run command terraform plan -out="flashcards.plan"
9. If everything went fine, Terraform will display the list of resources that going to be created, in case of error double-check your variables.
10. Once ready, execute terraform apply "flashcards.plan"

11. After successful completion, you'll see the IP address - you can browse to it or SSH.
12. Once completed, you can destroy all changes Terraform did with terraform destroy


