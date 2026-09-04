## Summary

<!-- Describe the change and its motivation. -->

## Validation

- [ ] `bash -n bin/agentic-route lib/core.sh install.sh`
- [ ] `bash tests/test_cli.sh`
- [ ] Documentation and package metadata reviewed

## Safety

- [ ] No secrets or environment-specific credentials were added
- [ ] IP routing or firewall behavior is unchanged, or the change is documented
- [ ] `net-safe` deadman switch preserved (no mutation without net-safe)
