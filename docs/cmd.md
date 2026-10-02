# Command Cheat Sheet

## One-time setup

```sh
az login
az account show                                              # confirm the subscription
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "azure-terraform"
export TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

Add the two `export` lines to your shell profile, or run them in each new terminal. `TF_VAR_<name>` sets the Terraform variable `<name>`.

## Check a module

```sh
cd modules/azure-vnet
terraform fmt -check -recursive    # formatting (drop -check to fix)
terraform init -backend=false
terraform validate
terraform test                     # all tests in tests/
terraform test -verbose            # also print plan/state per run
```

All modules at once, from the repo root:

```sh
terraform fmt -check -recursive
for m in modules/*/; do (cd "$m" && terraform init -backend=false -input=false >/dev/null && terraform test); done
```

Check a module's example (uses `source = "../.."`, so it tests your working copy):

```sh
cd modules/azure-vnet/examples/basic
terraform init -backend=false && terraform validate
terraform plan                     # needs ARM_SUBSCRIPTION_ID
```

## Release a module

```sh
# 1. change the module, add an entry to its CHANGELOG.md
git add modules/azure-vm
git commit -m "azure-vm: add custom_data input"
git push origin main

# 2. tag and push the tag
git tag azure-vm/v0.2.0
git push origin azure-vm/v0.2.0
```

```sh
git tag -l 'azure-vm/*'             # list a module's releases
git ls-remote --tags origin         # tags that actually exist on GitHub
git show azure-vm/v0.2.0 --stat     # what a release contains
git diff azure-vm/v0.1.0 azure-vm/v0.2.0 -- modules/azure-vm   # changes between releases
```

Tags are never moved or deleted once pushed. If a release is wrong, release a new version.

## Use a new release in the consumer

```sh
# edit ?ref=azure-vm/v0.2.0 in consumer-example/main.tf, then:
cd consumer-example
terraform init                     # re-downloads any module whose source string changed
terraform validate
terraform plan
```

```sh
terraform init -upgrade            # only needed when the source string is unchanged but the
                                   # target moved (?ref=main, version ranges, newer providers)
cat .terraform/modules/modules.json   # which module came from which source/ref
terraform providers                # provider requirements per module
```

## Plan

```sh
terraform plan                     # what would change
terraform plan -out=tfplan         # save the plan
terraform show tfplan              # read a saved plan
terraform show -json tfplan | jq '.resource_changes[] | {address, actions: .change.actions}'
```

Look for `+` create, `~` update in place, `-/+` replace (`forces replacement`), `-` destroy.

## Inspect and debug

```sh
terraform console                  # evaluate expressions, e.g. module.vnet.subnet_ids
terraform graph | dot -Tpng > graph.png   # dependency graph (needs graphviz)
TF_LOG=DEBUG terraform plan        # verbose provider/API logging
```

## Git: undo

```sh
git restore --staged <file>        # unstage, keep the edit
git restore <file>                 # discard an unstaged edit
git reset --soft HEAD~1            # undo last commit, keep changes staged
git reset HEAD~1                   # undo last commit, keep changes unstaged
git revert <sha>                   # undo a commit that is already pushed
git status -sb                     # "ahead N" = commits not pushed yet
git branch -r --contains <sha>     # has this commit been pushed?
```

Only `reset` commits that haven't been pushed. A secret that was pushed is leaked: rotate it.
