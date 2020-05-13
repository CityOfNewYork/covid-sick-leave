require 'aws-sdk-kms'

class KMS
    def initialize
        @client = Aws::KMS::Client.new(
            region: 'us-east-1', 
            access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
            secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
            session_token: ENV.fetch("AWS_SESSION_TOKEN")
        )
    end

    def decrypt(key)
        @client.decrypt({ciphertext_blob: Base64.decode64(key)}).plaintext
    end
end
