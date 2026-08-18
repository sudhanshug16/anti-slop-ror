# Repository guidance

- `lib/` and `config/` are canonical; generated `skills/install-anti-slop-ror/assets/anti_slop_ror/` mirrors them.
- Keep cops generic, AST-local, and no-autocorrect.
- Add focused specs, run `bin/sync-skill-assets`, then `bin/check`.
