# azure-vnet

Virtual network with subnets. Subnets can optionally be delegated to a service.

## Usage

```hcl
module "vnet" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vnet?ref=azure-vnet/v0.1.0"

  name                = "..."
  resource_group_name = "..."
  location            = "eastus2"
  address_space       = ["10.10.0.0/16"]

  subnets = {
    vm  = { address_prefixes = ["10.10.1.0/24"] }
    app = { address_prefixes = ["10.10.2.0/26"], delegation = "Microsoft.Web/serverFarms" }
  }
}
```

See `examples/basic` for a full working example, and `CHANGELOG.md` for released versions.

## Inputs

| Name | Type | Default |
|---|---|---|
| `name` | `string` | required |
| `resource_group_name` | `string` | required |
| `location` | `string` | required |
| `address_space` | `list(string)` | required |
| `subnets` | `map(object({ address_prefixes = list(string), delegation = optional(string) }))` | required |

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | VNet ID |
| `subnet_ids` | Map of subnet name → subnet ID |
