require 'base64'
require 'dotenv/load'
require 'json'
require 'openssl'
require 'parallel'
require 'mysql2'
require 'fileutils'

require './src/clients/mysql'
require './src/clients/sheets'
require './src/errors'
require './src/logger'
require './src/util'

module LambdaFunctions

    class EventHandler
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

        def self.process(event:, context:, db: MySQL.new)
            FileUtils.cp('./token.yaml', '/tmp/token.yaml')
            last_day = db.get_last_day()
            sheets = Sheets.new
            data = []
            last_day.each do |row|
                data.push([row["created_at"].strftime("%Y-%m-%d"), row["has_email"], row["type"]])
            end
            sheets.append(data)
            api_gateway_resp(statusCode: 204)
        end
    end
end


