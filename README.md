# MoneyPouch

MoneyPouch is a free, self-hosted expense tracker.

## Run it

Download the compose file into an empty folder.

```bash
curl -O https://raw.githubusercontent.com/kenyounot123/moneypouch/main/compose.yaml
```

Create a `.env` file next to it with a secret key.

```bash
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > .env
```

Start the app.

```bash
docker compose up -d
```

Open http://localhost:8080. Your data lives in the `moneypouch-data` volume.

## Upgrade

Back up the `moneypouch-data` volume first. Then pull the new image and restart.

```bash
docker compose pull && docker compose up -d
```

Migrations run on boot. To pin a version, replace `latest` in `compose.yaml` with a tag such as `0.1.0` or `0.1`.

## Releases

Versions follow semver. Each release publishes the image tags `X.Y.Z`, `X.Y`, and `latest` to `ghcr.io/kenyounot123/moneypouch`. The changelog is in `CHANGELOG.md` and on GitHub Releases.

Maintainers release by merging the release-please PR. It picks the next version from conventional commit titles. `feat` bumps the minor version and `fix` bumps the patch version. Until 1.0, a breaking change bumps the minor version too.
