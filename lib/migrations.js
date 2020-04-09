const shell = require('shelljs');

const STATUS = Object.freeze({ GOOD: 0 })
const SILENT = { silent: true }
const SEARCH_REPLACE_OPTS = `--recurse-objects --all-tables --precise --report-changed-only`;

/**
 * WordPress database migrations
 */
module.exports = {
  /**
   * Initialize the migration object
   */
  init: function ({ to, from, workDir }) {
    this.status = 0;

    this.workDir = workDir;
    this.from = from;
    this.to = to;

    return this;
  },

  /**
   * Check for stderr in the last command
   */
  checkStatus: function () {
    if (this.status !== STATUS.GOOD) {
      throw new Error(`Exit due to bad status.`);
    }

    return this;
  },

  /**
   * Change dir to bedrock
   */
  wpDirAvailable: function () {
    shell.cd(this.workDir, code => {
      this.status = code || 0;
    });

    return this;
  },

  /**
   * Check availability of a wp-cli alias
   */
  aliasAvailable: function (env) {
    shell.exec(`wp @${env} --info`, code => {
      this.status = code || 0;
    });

    return this;
  },

  /**
   * Export database
   */
  export: function (env) {
    shell.echo(`\nExporting @${env} database.`);
    this.status = shell.exec(`wp @${env} db export`).code;

    return this;
  },

  /**
   * Reset database
   */
  reset: function (env) {
    shell.echo(`\nResetting @${env} database.`)
    this.status = shell.exec(`\wp @${env} db reset --yes`).code;

    return this;
  },

  /**
   * Import database
   */
  import: function () {
    shell.echo(`\nImporting @${this.from.alias} database to @${this.to.alias}.`)
    this.status = shell.exec(`
      wp @${this.from.alias} db export - |
      wp @${this.to.alias}   db import -
    `).code;

    return this;
  },

  /**
   * Perform a search and replace operation on the database
   */
  replaceString: function (env, searchString, replaceString) {
    shell.echo(`\nReplacing '${searchString}' with '${replaceString}' on @${env}`)

    shell.exec(`
      wp @${env} search-replace '${searchString}' '${replaceString}' ${SEARCH_REPLACE_OPTS}
    `).code;

    return this;
  },

  /**
   * Flush the site obj cache
   */
  flush: function (env) {
    shell.echo(`\nFlushing cache on @${env}`)
    this.status = shell.exec(`wp @${env} cache flush`).code;

    return this;
  },

  /**
   * Clean a site comments table of spam
   */
  cleanComments: function (env) {
    shell.echo(`\nPurging spam comments from @${env} database`)

    this.status = shell.exec(`
      wp @${env} comment list --format=ids --status=spam |\
      xargs -I {} wp @${env} comment delete {}
    `).code

    return this;
  },

  /**
   * Run a health check on a database
   */
  healthCheck: function (env) {
    shell.echo(`\nRunning a health-check on @${env} database`)

    this.status = shell.exec(`wp @${env} db check`).code;

    return this;
  },

  /**
   * Optimize a database
   */
  optimize: function (env) {
    shell.echo(`\nOptimizing the @${env} database`)
    this.status = shell.exec(`wp @${env} db optimize --quiet`).code;

    return this;
  },

  /**
   * List a database's table sizes
   */
  info: function (env) {
    shell.echo(`\nFinal state of the @${env} database:`)
    this.status = shell.exec(`wp @${env} db size --all-tables`).code;

    return this;
  },

  /**
   * Run migration tasks
   */
  run: function () {
    this
      .wpDirAvailable()
        .checkStatus()

      .aliasAvailable(this.from.alias)
        .checkStatus()

      .aliasAvailable(this.to.alias)
        .checkStatus()

      .export(this.to.alias)
        .checkStatus()

      .reset(this.to.alias)
        .checkStatus()

      .import()
        .checkStatus()

      .cleanComments(this.to.alias)
        .checkStatus()

      .replaceString(
        this.to.alias,
        this.from.host,
        this.to.host,
      ).replaceString(
        this.to.alias,
        `//${this.from.host}`,
        `//${this.to.host}`
      ).replaceString(
        this.to.alias,
        `\\/\\/${this.from.host}`,
        `\\/\\/${this.to.host}`
      ).replaceString(
        this.to.alias,
        `${this.from.ssl ? `https` : `http`}://${this.to.host}`,
        `${this.to.ssl ? `https` : `http`}://${this.to.host}`
      ).checkStatus()

      .optimize(this.to.alias)
        .checkStatus()

      .flush(this.to.alias)
        .checkStatus()

      .healthCheck(this.to.alias)
        .checkStatus()

      .info(this.from.alias)
      .info(this.to.alias);

    return this;
  },
}
