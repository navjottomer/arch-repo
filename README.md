# arch-repo

Prebuilt Arch Linux packages that are not in the official repos, built by
GitHub Actions and published as a pacman repository.

| Package | What it is |
|---|---|
| `gearlever` | Manage AppImages |
| `python-ftputil` | FTP client library (Gear Lever needs it) |
| `python-desktop-entry-lib` | Desktop entry library (Gear Lever needs it) |

## Use it

Add this to `/etc/pacman.conf`, above `[core]`:

```ini
[navjottomer]
SigLevel = Optional TrustAll
Server = https://github.com/navjottomer/arch-repo/releases/download/repo
```

Then:

```bash
sudo pacman -Syu gearlever
```

## How it works

- `pkgbuilds/<name>/PKGBUILD` is one package.
- `build-order` lists the packages, so a package builds after the ones it needs.
- `.github/workflows/build.yml` builds them in an Arch container on every push
  to `pkgbuilds/` and every Monday, then uploads the result to the rolling
  release named `repo`.
- If the secret `GPG_PRIVATE_KEY` is set, packages and the database are signed.

## Add a package

1. Add `pkgbuilds/<name>/PKGBUILD` with real checksums.
2. Add the name to `build-order`, after its dependencies.
3. Push to `main`.
