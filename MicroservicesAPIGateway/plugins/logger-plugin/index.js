console.log("Loaded index.js")

module.exports= {
    version: '1.0.0',
    schema: {
      "$id": "https://express-gateway.io/schemas/plugins/custom-logger.json"
    },
    init: function (pluginContext) {
      pluginContext.registerPolicy(require('./policies/logger-policy'));
    },
  }
