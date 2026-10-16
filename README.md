<h1 align="center"><img src="docs/images/pouch.png" width="108" height="108" alt="The MoneyPouch pouch"><br>MoneyPouch</h1>

<p align="center">No budgets. No net worth. Just see where your money goes.<br>Log an expense in a few seconds, on your own server, for free.</p>

<p align="center">
  <a href="#getting-started">Getting started</a> ·
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
  <img src="docs/images/demo.gif" alt="Pressing Command K, typing Chip, pressing Tab to complete Chipotle, adding 11.25 yesterday, and pressing Enter. Chipotle appears in Recent and the October total goes up">
</p>

## Features
- **Fast entry.** Press ⌘K (Ctrl+K), type `Chipotle 11.25 yesterday`, and press Enter.
- **It remembers.** Tab completes names you have used, and their category comes back.
- **Your data, your server.** One container and one SQLite file, in a volume you own.
- **Bring your history.** Import an Excel or CSV file. Rows you already have are skipped, and you can undo the whole import.
- **Take it with you.** Download every transaction as a CSV file, any time.
- **Bank sync, optional.** Connect your own SimpleFIN account to pull in transactions from your bank accounts.

## What MoneyPouch is not

MoneyPouch is not a budgeting app. It has no envelopes, no "give every dollar a job", no net worth, and no investment tracking. Those features are good for some people, but most of us only want to know where the money went. MoneyPouch does that one job and stays fast.

## System requirements

MoneyPouch is light. The image is built for 64-bit x86 and ARM, so an old PC or a Raspberry Pi 4 or later has enough power to run it.

|      | Minimum | Recommended |
| ---- | ------- | ----------- |
| RAM  | 512 MB free | 1 GB free |
| CPU  | Any 64-bit x86 or ARM CPU | 2 cores |
| Disk | 2 GB free | 2 GB free |

Your data takes almost no space. Ten years of spending, 30,000 transactions, is about 5 MB.

These numbers come from running the Docker image with Docker's memory and CPU limits and loading pages as a user with 30,000 transactions. MoneyPouch used about 300 MB of memory and stopped working at a 256 MB limit. With a quarter of one CPU core, pages still loaded in about 0.1 to 0.2 seconds.

## Getting started

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

Then open `localhost:8080`. Keep `.env` next to `compose.yaml` and never change it. See [Backups and upgrades](#backups-and-upgrades) for why it matters and how to keep your data safe.

### First steps

1. Create your account.
2. Press ⌘K (Ctrl+K), type `Coffee 4.50`, and press Enter. That's your first expense.
3. Optional: connect your bank in Settings. See [Bank sync with SimpleFIN](#bank-sync-with-simplefin).

## Type it like you'd say it

<p align="center">
  <img src="docs/images/composer.png" alt="The composer reads Chipotle 11.25 yesterday as $11.25 at Chipotle, in Food, yesterday">
</p>

| | You type | MoneyPouch reads |
| :--- | :--- | :--- |
| **Amount** | `6.25` `$6.25` `1,650` | this is an expense/spending |
| **Money in** | `+2000` | income, not spending |
| **Date** | `yesterday` `sep 26` `friday` | that day, or today if left out |
| **Category** | `#food` | food, or if left out, the category you last used for that name |

## Bank sync with SimpleFIN

Bank sync is optional but highly recommended. When you turn it on, MoneyPouch reads your transactions through [SimpleFIN](https://www.simplefin.org/), an open protocol for sharing read-only financial data with apps. Here is why you can trust SimpleFIN:

1. **Read-only.** The [protocol](https://www.simplefin.org/protocol.html) has no way to move money. MoneyPouch can see your transactions, and that's all.
2. **Your bank login never reaches MoneyPouch.** You add your bank on the [SimpleFIN Bridge](https://bridge.simplefin.org), not in MoneyPouch. The Bridge hands bank connections to [MX](https://www.mx.com/) and says bank credentials never touch its own servers ([security](https://beta-bridge.simplefin.org/info/security)).
3. **One-time tokens.** You paste a setup token into MoneyPouch, which trades it once for a private access URL. A token that has already been used stops working, so a copied token is useless.
4. **Stored encrypted, on your server.** MoneyPouch encrypts the access URL in your own database. Nothing passes through a MoneyPouch service, because there isn't one.
5. **You can cut it off.** Revoke MoneyPouch's access on the Bridge at any time, or disconnect in MoneyPouch's Settings, which deletes the access URL.
6. **Open about problems.** SimpleFIN publishes its incidents, including an MX bug in May 2026 that briefly showed some users each other's transactions. Bank credentials were not exposed.

The Bridge is a paid service, billed by SimpleFIN directly ([pricing](https://beta-bridge.simplefin.org/)). Read its [privacy policy](https://beta-bridge.simplefin.org/info/privacy) and [terms](https://beta-bridge.simplefin.org/info/terms) before you connect.

## Backups and upgrades

If you installed with ONCE, it handles backups and upgrades for you. The rest of this section is for Docker Compose.

The Docker Compose install keeps one secret in `.env`, created by the second install command. `openssl rand -hex 64` prints 64 random bytes as 128 hex characters. Rails uses `SECRET_KEY_BASE` to sign the cookie that keeps you signed in, and to derive the key that encrypts your SimpleFIN connection.

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

## Why I built MoneyPouch
I was first using Excel to track my expenses via a simple layout that summed up spending and income based on categories. This was bothersome to set up and the appearance/UI was also ugly (maybe I'm just bad with excel as well). So I looked into other popular finance apps, but most of them want you to budget, and that leads to bloated features that overwhelm someone who just wants to track where their money is going. YNAB makes you give every dollar a job before you spend it. Monarch and Copilot add investment tracking, net worth and bank syncing on top of budgets, and both cost about $100 a year. Rocket Money is built around subscriptions and bill negotiation, and the self-hosted options are either another envelope budgeting tool (Actual Budget) or full double-entry accounting (Firefly III). I didn’t need any of that and I also was not going to pay for something like that. I wanted a fast, good-looking way to log an expense in a few seconds and see where my money goes. So I built MoneyPouch.

## Contributing

Found a bug or have an idea? Open an [issue](https://github.com/kenyounot123/moneypouch/issues). To work on the code, clone the repo and run `bin/setup`.

---

© 2026 MoneyPouch. Free and open source under the [MIT License](LICENSE).
