require 'base64'
require 'dotenv/load'
require 'json'
require 'openssl'
require 'parallel'
require 'mysql2'

require './src/clients/ses'
require './src/clients/mysql'
require './src/clients/sns'
require './src/logger'
require './src/util'

require './src/handlers/covid'

PROCESS_EVENT = "PROCESS_EVENT"
FORMSTACK_WEBHOOK_EVENT = "FORMSTACK_EVENT"
BOX_WEBHOOK_EVENT = "BOX_EVENT"

module LambdaFunctions

    class EventHandler

        def self.setup
            # place pdftk executable on PATH
            ENV.store('PATH', ENV.fetch('PATH') + ':' + ENV.fetch('LAMBDA_TASK_ROOT', "/var/task") + '/lib')
        end

        def self.api_gateway_resp(statusCode:, body: nil)
            if body
                {
                    "isBase64Encoded": false,
                    "statusCode": statusCode,
                    "headers": {},
                    "body": JSON.generate(body)
                }
            else
                {
                    "isBase64Encoded": false,
                    "statusCode": statusCode,
                    "headers": {}
                }
            end
        end

        # AWS lambda calls self.process
        # :nocov:
        def self.process(event:, context:, sns: SNS.new, ses: SES.new, db: MySQL.new)
            begin
                setup
                verify_formstack_webhook(event)
                COVIDHandler.new(JSON.parse(event["body"]), ses, db).process

            rescue ForbiddenError => err
                Logger.error("msg: #{err}, trace: #{err.backtrace.join("\n")}")
                sns.publish("Online Apps Error", "msg: #{err}, event: #{event}")
                api_gateway_resp(statusCode: 403, body: {"error": err})

            rescue StandardError => err
                Logger.error("msg: #{err}, trace: #{err.backtrace.join("\n")}")
                sns.publish("Online Apps Error", "msg: #{err}, event: #{event}")
                api_gateway_resp(statusCode: 500, body: {"error": err})

            else
                api_gateway_resp(statusCode: 204)

        end
        # :nocov:
    end
end


