terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Root module should specify the maximum provider version
      # The ~> operator is a convenient shorthand for allowing only patch releases within a specific minor release.
      version = "~> 3.26"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  location = "East US"
}

data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "function-app-python"
  output_path = "function-app-python.zip"
}

data "archive_file" "file_function_app1" {
  type        = "zip"
  source_dir  = "function-app-python1"
  output_path = "function-app-python1.zip"
}


module "linux_consumption" {
  source = "./modules/fa"

  project  = "tf-publish-sas"
  location = local.location

  archive_file = data.archive_file.file_function_app
  archive_file1= data.archive_file.file_function_app1
}