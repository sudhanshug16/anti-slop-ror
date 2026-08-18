---
name: install-anti-slop-ror
description: Vendor the Anti Slop Rails cops into a Rails repository.
---

Run `ruby scripts/install.rb TARGET`, where `TARGET` already exists and is the project directory. The copied plugin is a snapshot: rerun the installer to update it. The installer refuses to overwrite an existing `TARGET/tools/anti_slop_ror`; use `--force` only to intentionally replace that snapshot. It does not edit other target files; add the printed StandardRB plugin block, then run its printed blocking verification command.
