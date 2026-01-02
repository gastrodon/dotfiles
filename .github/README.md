# GitHub Actions Workflows

## Validate NixOS Modules

The `build-nixos.yml` workflow automatically validates the syntax of NixOS modules to ensure they are correctly formatted.

### What it does

1. **Runs in NixOS Container** - Uses official NixOS Docker container for validation
2. **Configures NixOS 25.11** - Sets up NixOS 25.11 channel for validation
3. **Validates Modules** - Checks syntax of all `.nix` files in the `module/` directory
4. **Reports Results** - Lists validated modules and reports any syntax errors

### When it runs

- On push to `main` or `copilot/create-nix-module-documentation` branches
- On pull requests to `main`
- Manually via workflow dispatch

### Configuration

The workflow uses:
- **NixOS Docker container** (`nixos/nix:latest`)
- **nixos-25.11** channel for reproducible validation
- Runs directly on NixOS instead of Ubuntu with Nix installed

### Viewing Results

Validation results appear in:
- GitHub Actions tab for detailed logs
- Pull request checks for quick status
- Job summary with module listing and NixOS version

### Local Testing

To test module syntax locally before pushing:

```bash
# Install Nix if not already installed
curl -L https://nixos.org/nix/install | sh

# Validate a specific module
nix-instantiate --parse module/users.nix

# Validate all modules
for module in module/*.nix; do
  echo "Checking $module"
  nix-instantiate --parse "$module"
done
```

### Available Modules

The repository contains modular NixOS configurations in the `module/` directory:
- `users.nix` - User account configuration
- `x11.nix` - X Window System setup
- `i3.nix` - i3 window manager
- `firefox.nix` - Firefox browser with policy templates

These modules are designed to be imported into your main NixOS configuration.

### Troubleshooting

**Syntax errors:**
- Run `nix-instantiate --parse <file>.nix` locally to check syntax
- Ensure all Nix expressions are properly closed (braces, brackets)
- Check for missing semicolons or commas in attribute sets

**Module not found:**
- Verify the module file exists in the `module/` directory
- Ensure file permissions are correct (readable)
