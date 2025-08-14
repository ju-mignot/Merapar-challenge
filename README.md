## Merapar Challenge

On a cloud platform of your choice provision a service, using Infrastructure as Code, that serves a html page.
The content of the page must be ..

<h1>The saved string is dynamic string</h1>   

.. Where dynamic string can be set to whatever is requested without having to re-deploy. When you demonstrate the solution in the interview you will need to modify the string to show it works. Any user accessing the url must get the same result. 


## Prerequisites
1. AWS CLI installed and AWS credentials configured (for example via `aws configure`)
2. Terraform installed (version `>= 1.6`) 


## Proposed solution
1. Tech stack: 
  - AWS
  - Terraform
  - Python
2. Overview:
  This solution deploys an API Gateway that invoke a Lambda function that renders the HTML page:
    <h1>The saved string is {dynamic string}</h1>
  Where the {dynamic string} is stored in AWS Systems Manager Parameter Store, so it can be updated with no redeployment. 


## Deploy
1. From the `tf/` directory:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```
2. Copy/Paste the URL shown in the output (`url`) in your browser.


## Update the dynamic string 
1. Run the following command 
```bash
aws ssm put-parameter --name "merapar_challenge-dynamic_string" --type String --value "MY_STR_VALUE" --overwrite
```
2. Reload the webpage to see the updated value.


## Destoy
1. From the `tf/` directory:
```bash
terraform destroy
```

