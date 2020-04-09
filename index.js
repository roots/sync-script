#!/usr/bin/env node
const { readFileSync, writeFileSync } = require('fs')
const { join, resolve } = require ('path')
const migrations = require('./lib/migrations')
const meow = require('meow');

const migrate = meow(`
  Roots DB Migration Tool

	Usage
    $ roots-migrate run
    $ roots-migrate generate-config

  Options
    --from -f  origin
    --to   -t  destination

  Example
    $ roots-migrate run --from production --to development
    $ roots-migrate generate-config
`, {
  autoHelp: true,
  version: '1.0.0',
  flags: {
    from: {
      type: 'string',
      alias: 'f',
      default: 'production',
    },
    to: {
      type: 'string',
      alias: 't',
      default: 'development',
    },
  },
});

const configPath = join(process.cwd(), `migrations.config.js`);

if (migrate.input[0] == 'generate-config') {
  const templatePath = resolve(__dirname, '_configTemplate.js');
  const contents = readFileSync(templatePath)

  writeFileSync(configPath, contents)

  console.log(`Config file published to ${configPath}`)
  process.exit(1)
}

const config = require(configPath)

if (! config) {
  console.error('No config found')

  process.exit(1)
} else if (! config[`${migrate.flags.to}`] || ! config[`${migrate.flags.from}`]) {
  ! config[migrate.flags.to]
    && console.error(`No config entry for @${migrate.flags.to} found in ${configPath}`)

  ! config[migrate.flags.from]
    && console.error(`No config entry for @${migrate.flags.from} found in ${configPath}`)

  process.exit(1)
}

const workDir = process.cwd()

const from = config[migrate.flags.from]
from.alias = migrate.flags.from

const to = config[migrate.flags.to]
to.alias = migrate.flags.to

if (migrate.input[0] == 'run') {
  migrations.init({ from, to, workDir }).run();
}

process.exit(0)
