<h1 align="center"><img src="docs/images/pouch.png" width="108" height="108" alt="The MoneyPouch pouch"><br>MoneyPouch</h1>

<p align="center">A free, self-hosted expense tracker with fast manual entry and optional bank syncing</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> ·
  <a href="https://github.com/kenyounot123/moneypouch/releases">Releases</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="https://github.com/kenyounot123/moneypouch/issues">Issues</a>
</p>

<p align="center">
  <a href="https://github.com/kenyounot123/moneypouch/releases"><img src="https://img.shields.io/github/v/release/kenyounot123/moneypouch?label=release&color=3E446D" alt="Latest release"></a>
  <a href="https://github.com/kenyounot123/moneypouch/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/kenyounot123/moneypouch/ci.yml?branch=main&label=ci&color=3E446D" alt="CI status"></a>
  <a href="https://github.com/kenyounot123/moneypouch/pkgs/container/moneypouch"><img src="https://img.shields.io/badge/image-ghcr.io-3E446D" alt="Docker image on ghcr.io"></a>
</p>

<p align="center">
  <img src="docs/images/overview.png" alt="The MoneyPouch Overview, with October spending by category and the latest transactions">
</p>

## Why MoneyPouch?

Most finance apps want you to budget. MoneyPouch only asks what you spent, and makes typing it in faster than opening your bank's app.

- **Fast entry.** Press ⌘K (Ctrl+K), type `Blue Bottle 6.25 yesterday`, and press Enter.
- **It remembers.** Tab completes names you have used, and their category comes back.
- **Your data, your server.** One container and one SQLite file, in a volume you own.
- **Bank sync, optional.** Connect your own SimpleFIN account to pull in transactions.

## Type it like you'd say it

<p align="center">
  <img src="docs/images/composer.png" alt="The composer reads Blue Bottle 6.25 yesterday as $6.25 at Blue Bottle, in Food, yesterday">
</p>

| | You type | MoneyPouch reads |
| :--- | :--- | :--- |
| **Amount** | `6.25` `$6.25` `1,650` | Money out |
| **Money in** | `+2000` | Income, not spending |
| **Date** | `yesterday` `sep 26` `friday` | That day, or today if left out |
| **Category** | `#food` | Food, or that name's last category |

## Quickstart

Pick one of two ways to run MoneyPouch.

### Install with ONCE

Use [ONCE](https://github.com/basecamp/once) on Linux or macOS. This is the recommended way.

1. Install ONCE.

   ```bash
   curl https://get.once.com | sh
   ```

2. In the ONCE dashboard, choose to install from a Docker image.
3. Enter the image `ghcr.io/kenyounot123/moneypouch:latest`.
4. Enter a hostname. If you point a domain at the machine, ONCE sets up HTTPS for it. `moneypouch.localhost` works on this machine only.

ONCE creates and keeps the secret key for you, backs up your data daily and keeps 30 days of backups, and installs updates.

### Install with Docker Compose

Use Docker Compose on any system that runs Docker, including Windows. Run these commands in an empty folder.

```bash
curl -O https://raw.githubusercontent.com/kenyounot123/moneypouch/main/compose.yaml
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > .env
docker compose up -d
```

Then open `localhost:8080` and create your account.

The second command creates the `.env` file. `openssl rand -hex 64` prints 64 random bytes as 128 hex characters. Rails uses `SECRET_KEY_BASE` to sign the cookie that keeps you signed in, and to derive the key that encrypts your SimpleFIN connection.

The value must be secret and random, so nobody can forge a sign-in. It must also stay the same. If you lose or change `.env`, everyone is signed out and you must reconnect SimpleFIN. Keep `.env` next to `compose.yaml` and back it up with your data.

Your data lives in a Docker volume. Compose puts the folder name in front of the volume name, so in a folder called `moneypouch` the volume is `moneypouch_moneypouch-data`. Run these commands from the same folder and you never need to type the name.

To back up, stop the app and save the volume to a file next to `compose.yaml`:

```bash
docker compose stop
docker compose run --rm --no-deps -T --entrypoint tar app czf - -C /rails storage > moneypouch-backup.tgz
docker compose start
```

Keep `moneypouch-backup.tgz` and `.env` together. To restore, stop the app, then run:

```bash
docker compose run --rm --no-deps -T --entrypoint tar app xzf - -C /rails < moneypouch-backup.tgz
```

To upgrade, back up first. Then run `docker compose pull && docker compose up -d`.

## Contributing

Found a bug or have an idea? Open an [issue](https://github.com/kenyounot123/moneypouch/issues). To work on the code, clone the repo and run `bin/setup`.

---

© 2026 MoneyPouch. Free and open source under the [MIT License](LICENSE).
