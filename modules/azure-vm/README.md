# azure-vm

Linux VM (Ubuntu 24.04) with a NIC in the given subnet. SSH key authentication only, no public IP.

## Usage

```hcl
module "vm" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vm?ref=azure-vm/v0.1.0"

  name                = "..."
  resource_group_name = "..."
  location            = "eastus2"
  subnet_id            = module.vnet.subnet_ids["vm"]
  admin_ssh_public_key = var.admin_ssh_public_key
}
```

See `examples/basic` for a full working example, and `CHANGELOG.md` for released versions.

## Inputs

| Name | Type | Default |
|---|---|---|
| `name` | `string` | required |
| `resource_group_name` | `string` | required |
| `location` | `string` | required |
| `subnet_id` | `string` | required |
| `admin_ssh_public_key` | `string` | required |
| `admin_username` | `string` | `"azureuser"` |
| `size` | `string` | `"Standard_B2s"` |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | VM ID |
| `private_ip_address` | Private IP of the NIC |
