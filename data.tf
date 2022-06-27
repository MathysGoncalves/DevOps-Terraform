data "azurerm_resource_group" "tp4" { 
   name   =   "devops-TP2" 
} 

data "azurerm_virtual_network" "tp4" {
  name = "example-network"
  resource_group_name = data.azurerm_resource_group.tp4.name
}

data "azurerm_subnet" "tp4" {
  name                 = "internal"
  virtual_network_name = data.azurerm_virtual_network.tp4.name
  resource_group_name  = data.azurerm_resource_group.tp4.name
}