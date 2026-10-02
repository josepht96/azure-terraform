# Modules and Consumer

Three small Azure modules, each versioned on its own, and one consumer that pulls them from GitHub by tag.

| Module | Directory | Tag format |
|---|---|---|
| Virtual network | `modules/azure-vnet` | `azure-vnet/vX.Y.Z` |
| Virtual machine | `modules/azure-vm` | `azure-vm/vX.Y.Z` |
| App Service | `modules/azure-app-service` | `azure-app-service/vX.Y.Z` |

## How they fit together

The modules don't know about each other. The consumer creates a resource group and passes outputs from one module into inputs of another:

```
consumer-example
  ├── resource group
  ├── azure-vnet ── subnet_ids["vm"]  ──► azure-vm          (subnet_id)
  │             └── subnet_ids["app"] ──► azure-app-service (vnet_integration_subnet_id)
```

## Module contracts

Every module takes `name`, `resource_group_name`, and `location` (all `string`, required), plus the inputs below.

### azure-vnet

| Input | Type | Default |
|---|---|---|
| `address_space` | `list(string)` | required |
| `subnets` | `map(object({ address_prefixes = list(string), delegation = optional(string) }))` | required |

The map key is the subnet name. `delegation` is a service name such as `"Microsoft.Web/serverFarms"`.

| Output | Description |
|---|---|
| `vnet_id` | VNet ID |
| `subnet_ids` | Map of subnet name → subnet ID |

### azure-vm

Linux VM, SSH key only, Ubuntu 24.04.

| Input | Type | Default |
|---|---|---|
| `subnet_id` | `string` | required |
| `admin_ssh_public_key` | `string` | required |
| `admin_username` | `string` | `"azureuser"` |
| `size` | `string` | `"Standard_B2s"` |

| Output | Description |
|---|---|
| `vm_id` | VM ID |
| `private_ip_address` | NIC private IP |

### azure-app-service

Linux Web App running a container, with its own `B1` service plan.

| Input | Type | Default |
|---|---|---|
| `docker_image` | `string` | `"nginx:latest"` |
| `vnet_integration_subnet_id` | `string` | `null` |

| Output | Description |
|---|---|
| `app_id` | Web app ID |
| `default_hostname` | `*.azurewebsites.net` hostname |

## The consumer

`consumer-example/main.tf`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000" # placeholder; never applied
}

variable "admin_ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAA-placeholder"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo"
  location = "eastus2"
}

module "vnet" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vnet?ref=azure-vnet/v0.1.0"

  name                = "vnet-demo"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.10.0.0/16"]

  subnets = {
    vm  = { address_prefixes = ["10.10.1.0/24"] }
    app = { address_prefixes = ["10.10.2.0/26"], delegation = "Microsoft.Web/serverFarms" }
  }
}

module "vm" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-vm?ref=azure-vm/v0.1.0"

  name                 = "vm-demo"
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  subnet_id            = module.vnet.subnet_ids["vm"]
  admin_ssh_public_key = var.admin_ssh_public_key
}

module "app" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-app-service?ref=azure-app-service/v0.1.0"

  name                       = "app-demo"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  vnet_integration_subnet_id = module.vnet.subnet_ids["app"]
}
```

### Things to know about git sources

- `//` separates the repo URL from the subdirectory inside it.
- `?ref=` is the version. Git sources don't support the `version =` argument (that's only for registry modules).
- `source` must be a literal string. No variables, no locals.
- After changing a `ref`, run `terraform init -upgrade`.
- Downloaded modules live in `.terraform/modules/`; see `.terraform/modules/modules.json` for what was fetched.
- `.terraform.lock.hcl` locks **providers only**, not modules. The pinned tag is your only lock, so always pin a tag rather than a branch.

## Build order

1. Build the three modules with `examples/basic` (relative source). Check each with `terraform init -backend=false && terraform validate`.
2. Commit, push, and tag all three at `v0.1.0`.
3. Build `consumer-example/` pinned to the `v0.1.0` tags. `terraform init && terraform validate`.

## Experiments

Once the consumer validates, try these. Each one shows something you can talk about in an interview.

1. **Independent versions.** Add an optional `custom_data` input to `azure-vm`, release `azure-vm/v0.2.0`, and bump only the VM `ref` in the consumer. VNet and App Service stay at `v0.1.0`.
2. **Breaking change.** Rename the `azure-vnet` output `subnet_ids` to `subnets`, release `azure-vnet/v0.2.0`, and bump the consumer. `validate` fails until the consumer is updated. This is why output names are part of the contract.
3. **Forgot to upgrade.** Change a `ref` and run `terraform validate` without `init -upgrade`. Read the error.
4. **Pin to a branch.** Point one module at `?ref=main`, push an unrelated change to the module, and run `init -upgrade` again. The consumer silently picks it up, which is why you pin tags.
5. **Tag before it exists.** Bump a `ref` to a tag you haven't pushed yet and run `init`. This is the release-ordering problem from `CLAUDE.md`.
