# azure-terraform

A learning repo for one question: **how does a Terraform consumer pull modules from a git repo by tag?**

The modules and a consumer live in the same repo, but the consumer references the modules through GitHub tags, exactly as it would if they were in a separate repo. Nothing is deployed to Azure; `terraform init` and `terraform validate` are the goal.

See `docs/consumer.md` for the modules and the consumer.

## Layout

```
azure-terraform/
├── modules/
│   └── <module-name>/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── CHANGELOG.md
│       ├── README.md
│       └── examples/basic/    # source = "../.." (local working copy)
├── consumer-example/          # source = "git::...?ref=<module>/vX.Y.Z" (released tags only)
├── docs/consumer.md
└── CLAUDE.md
```

## Rules

- **Examples use relative paths, the consumer uses git refs.** `modules/*/examples/basic` uses `source = "../.."` so it tests the code in front of you. `consumer-example/` only uses `git::https://...?ref=<tag>` so it tests what is released.
- **Modules never reference each other.** The consumer wires them together by passing outputs into inputs.
- **No `provider` blocks in modules.** Modules declare `required_providers` with a minimum version (`azurerm >= 4.0`); the consumer configures the provider.
- **Keep modules small.** Only the inputs and outputs listed in `docs/consumer.md`.

## Versioning

Each module has its own version, carried by a git tag:

```
<module-name>/v<MAJOR>.<MINOR>.<PATCH>      e.g. azure-vm/v0.2.0
```

- **MAJOR:** breaks the consumer (removed/renamed input or output, new required input).
- **MINOR:** adds something optional (new input with a default, new output).
- **PATCH:** fixes that don't change the interface.

While a module is at `0.x`, breaking changes bump MINOR instead of MAJOR.

Add a line to the module's `CHANGELOG.md` for each release. Tags are created by hand and never moved or deleted:

```sh
git tag azure-vm/v0.2.0
git push origin azure-vm/v0.2.0
```

## Release flow

A tag must exist on GitHub before the consumer can use it, so a change always takes two steps:

1. Change the module, update its `CHANGELOG.md`, commit, push, tag, push the tag.
2. Bump that module's `?ref=` in `consumer-example/`, then `terraform init -upgrade && terraform validate`.

## Checks

For each module, its example, and the consumer:

```sh
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

No Azure credentials are needed for any of these.
