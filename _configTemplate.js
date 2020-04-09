module.exports = {
  development: {
    ssl: false,
    host: 'example.test',
  },
  staging: {
    ssl: true,
    host: 'staging.example.com',
  },
  production: {
    ssl: true,
    host: 'example.com',
  },
}
