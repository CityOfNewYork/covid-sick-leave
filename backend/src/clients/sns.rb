require 'aws-sdk-sns'

require './src/logger'

class SNS
    def initialize
        @client = Aws::SNS::Client.new(
            region: 'us-east-1', 
            access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
            secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
            session_token: ENV.fetch("AWS_SESSION_TOKEN")
        )
    end

    def publish(subject, message)
        @client.publish({
            topic_arn: ENV.fetch('SNS_ARN'),
            message: message,
            subject: "[ONLINE APPS SNS] #{subject}"
        })
    end
end
