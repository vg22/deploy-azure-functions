variable "project" {
  type = string
}

variable "location" {
  type = string
}

variable "archive_file" {
  
}
variable "archive_file1" {
  
}

locals {
  funcapps={
  "func1": "${var.archive_file}",
  "func2": "${var.archive_file1}"
}
}
resource "azurerm_resource_group" "resource_group" {
  name = "${var.project}-resource-group"
  location = var.location
}

resource "azurerm_storage_account" "storage_account" {
  name = "${replace(var.project, "-", "")}strg"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
    name = "${var.project}-storage-container-functions"
    storage_account_name = azurerm_storage_account.storage_account.name
    container_access_type = "private"
}

# data "azurerm_storage_account_blob_container_sas" "storage_account_blob_container_sas" {
#   connection_string = azurerm_storage_account.storage_account.primary_connection_string
#   container_name    = azurerm_storage_container.storage_container.name
# }

resource "azurerm_service_plan" "app_service_plan" {
  name                = "${var.project}-app-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = var.location
  sku_name ="Y1"
  os_type = "Linux"
}

resource "azurerm_storage_blob" "storage_blob" {
  for_each = tomap(local.funcapps)
    # name = "${filesha256(var.archive_file.output_path)}.zip"
        name = "${filesha256(each.value.output_path)}.zip"

    storage_account_name = azurerm_storage_account.storage_account.name
    storage_container_name = azurerm_storage_container.storage_container.name
    type = "Block"
    source = "${each.value.output_path}"
}

resource "azurerm_linux_function_app" "function_app" {
  for_each = tomap(local.funcapps)
  name                       = "${var.project}-function-app${each.key}"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = var.location
  service_plan_id        = azurerm_service_plan.app_service_plan.id
  app_settings = {
    # "WEBSITE_RUN_FROM_PACKAGE"    = "https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}/${azurerm_storage_blob.storage_blob.name}${data.azurerm_storage_account_blob_container_sas.storage_account_blob_container_sas.sas}",
        "WEBSITE_RUN_FROM_PACKAGE"    = "https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}/${azurerm_storage_blob.storage_blob["${each.key}"].name}"

    "FUNCTIONS_WORKER_RUNTIME" = "Python"
      }
  site_config {
    application_stack{
      python_version = "3.9"
    }
  }
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  identity {
    type ="SystemAssigned"
  }
}

resource "azurerm_role_assignment" "blob-to-funcapp" {
  for_each             = azurerm_linux_function_app.function_app
  scope                = "/subscriptions/88402329-171c-4c63-8d8b-198e5d7cd5d3"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value.identity[0].principal_id
}

# output "function_app_default_hostname" {
#   value = azurerm_linux_function_app.function_app.default_hostname
# }
