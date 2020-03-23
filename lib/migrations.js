const shell = require('shelljs');

const STATUS = Object.freeze({
  GOOD: 0,
})

/**
 * WordPress database migrations
 */
module.exports = {
  /**
   * Initialize the migration object
   */
  init: function ({ bedrock, from, to, strings }) {
    /** Initialize status */
    this.status = 0;

    /** local site directory */
    this.bedrock = bedrock;

    /** origin site wp-cli alias */
    this.from = from;

    /** destination site wp-cli alias */
    this.to = to;

    /** search/replace pairs */
    this.strings = strings;

    /** return self */
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
    shell.cd(this.bedrock, { silent: true }, function (code, stdout, stderr) {
      this.status = code || 0;
    });

    return this;
  },

  /**
   * Check availability of a wp-cli alias
   */
  aliasAvailable: function (env) {
    shell.exec(`wp @${env} --info`, { silent: true }, function (code, stdout, stderr) {
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
    this.status = shell.exec(`wp @${env} db reset --yes`).code;

    return this;
  },

  /**
   * Import database
   */
  import: function (from, to) {
    shell.echo(`\nImporting @${from} database to @${to}.`)
    this.status = shell.exec(
      `wp @${from} db export - |\
       wp @${to}   db import -`
    ).code;

    return this;
  },

  /**
   * Perform a set of search and replace operations on the database
   */
  replaceStrings: function () {
    this.strings.forEach(({ search, replace }) => {
      this.status = this.replaceString(this.to, search, replace)
      this.checkStatus()
    });

    return this;
  },

  /**
   * Perform a search and replace operation on the database
   */
  replaceString: function (env, searchString, replaceString) {
    const options = `--recurse-objects --all-tables --precise --report-changed-only`;

    shell.echo(`\nReplacing '${searchString}' with '${replaceString}' on @${env}`)
    return shell.exec(`wp @${env} search-replace '${searchString}' '${replaceString}' ${options}`).code;
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
    this.status = shell.exec(
      `wp @${env} comment list --format=ids --status=spam |\
       xargs -I {} wp @${env} comment delete {}`
    ).code

    return this;
  },

  /**
   * Run a health check on a database
   */
  healthCheck: function (env) {
    shell.echo(`\nRunning a health-check on @${env} database`)
    this.status = shell.exec(`wp @${env} db check`, { silent: true }).code;

    return this;
  },

  /**
   * Optimize a database
   */
  optimize: function (env) {
    shell.echo(`\nOptimizing the @${env} database`)
    this.status = shell.exec(`wp @${env} db optimize --quiet`, { silent: true }).code;

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

      .aliasAvailable(this.from)
        .checkStatus()

      .aliasAvailable(this.to)
        .checkStatus()

      .export(this.to)
        .checkStatus()

      .reset(this.to)
        .checkStatus()

      .import(this.from, this.to)
        .checkStatus()

      .cleanComments(this.to)
        .checkStatus()

      .replaceStrings()
        .checkStatus()

      .optimize(this.to)
        .checkStatus()

      .flush(this.to)
        .checkStatus()

      .healthCheck(this.to)
        .checkStatus()

      .info(this.from)
      .info(this.to);

    return this;
  },
}
