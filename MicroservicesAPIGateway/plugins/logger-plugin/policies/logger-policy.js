const winstonLogger=require('./winstonLogger');

module.exports= {
    name: 'custom-logger',
    schema: {
      $id: 'http://express-gateway.io/schemas/policies/custom-logger.json',
      type: 'object',
      properties: {
        message: {
          type: 'string',
          default: ''
        }
      }
    },
    policy: (actionParams) => {
      return (req, res, next) => {
        winstonLogger.info(`Received a request on ${req.protocol}://${req.headers.host}${req.originalUrl}`);
        next() // calling next policy
      };
    }
  };

