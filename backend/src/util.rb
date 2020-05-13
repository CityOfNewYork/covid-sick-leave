require 'date'
require 'fileutils'

require './src/logger'

def create_dir_unless_exists(dirpath)
    unless File.directory?(dirpath)
        FileUtils.mkdir_p(dirpath)
    end
end

def verify_formstack_webhook(req)
    request_hash = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch('FORMSTACK_HMAC_KEY'), req["body"])}"
    if req["headers"]["X-FS-Signature"] != request_hash
        raise ForbiddenError.new("Received formstack webhook without matching signature." + 
            "Expected: #{request_hash}. " + 
            "Received: #{req["headers"]["box-signature-primary"]}. " +
            "Request: #{req}")
    end
end


