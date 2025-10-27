terraform {
  backend "s3" {
    bucket = "react-project-ansible-terraform"
    
    key    = "react-app-automation/terraform.tfstate"
    
    region = "us-east-1"
  }
}
