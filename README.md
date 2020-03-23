# Roots Migrate

```sh
roots-migrate

Usage
  $ roots-migrate run
  $ roots-migration generate-config

Options
  --from -f  origin
  --to   -t  destination

Example
  $ roots-migrate run --from production --to development
  $ roots-migrate generate-config
```

## Installation

yarn global add @roots/sync-script

## Configuration

In your project root, generate a config skeleton:

```sh
roots-migrate generate-config
```

Add search and replace strings here.

## Usage

In your project root, run a migration:

```sh
roots-migrate run --from {origin handle} --to {destination handle}
```

You can also run in case you forget.

```
roots-migrate --help
```

## Requirements

**WP-CLI must be installed on all environments (local and remote).**

### WP-CLI aliases

WP-CLI aliases must be properly setup in order for the sync script to work. Open `wp-cli.yml` and setup the aliases for your environments.

#### Trellis WP-CLI aliases

```yml
# site/wp-cli.yml
path: web/wp

@development:
  ssh: vagrant@example.test/srv/www/example.com/current
@staging:
  ssh: web@staging.example.com/srv/www/example.com/current
@production:
  ssh: web@example.com/srv/www/example.com/current
```

Test the aliases to make sure they're working:

```sh
$ wp @development
$ wp @staging
$ wp @production
```

#### Trellis + Kinsta WP-CLI aliases

```yml
# site/wp-cli.yml
path: web/wp

@development:
  ssh: vagrant@example.test/srv/www/example.com/current
@staging:
  ssh: example@1.2.3.4:54321/www/example_123/public/current/web
@production:
  ssh: example@1.2.3.4:12345/www/example_123/public/current/web
```

### `.gitignore`

Open `.gitignore` in your Bedrock directory (`site/`) and add the following:

```
# WP-CLI
*_development*.sql
```

When you sync down to your local development environment a database backup is performed with `wp db export`. This helps you safely recover your database if you accidentally sync, and by making this modification to `.gitignore` you're ensuring that your local database export doesn't accidentally get commited to your git repository.

## Troubleshooting

### Unable to connect to development

Make sure that your local development setup is up and running.

### Unable to connect to production or staging

Make sure that you're able to successfully connect with a SSH connection with the same details configured for the same WP-CLI alias.

If your SSH connection doesn't fail, make sure WordPress is first already installed.

## Support

[Shoot me an email](mailto:ben@roots.io) with any issues you run into.

You can re-download the latest version by visiting [https://roots.io/product-links/](https://roots.io/product-links/).
