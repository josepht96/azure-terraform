# azure-app-service

Linux Web App running a Docker Hub container on its own B1 service plan, with optional outbound VNet integration.

## Usage

```hcl
module "app" {
  source = "git::https://github.com/josepht96/azure-terraform.git//modules/azure-app-service?ref=azure-app-service/v0.1.0"

  name                = "..."
  resource_group_name = "..."
  location            = "eastus2"
  vnet_integration_subnet_id = module.vnet.subnet_ids["app"]
}
```

See `examples/basic` for a full working example, and `CHANGELOG.md` for released versions.

## Inputs

| Name | Type | Default |
|---|---|---|
| `name` | `string` | required |
| `resource_group_name` | `string` | required |
| `location` | `string` | required |
| `docker_image` | `string` | `"nginx:latest"` |
| `vnet_integration_subnet_id` | `string` | `null` |

## Outputs

| Name | Description |
|---|---|
| `app_id` | Web app ID |
| `default_hostname` | `*.azurewebsites.net` hostname |
