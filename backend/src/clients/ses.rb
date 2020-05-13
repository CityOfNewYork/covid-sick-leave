
require 'aws-sdk-ses'
require 'base64'
require 'mime'

require './src/logger'

class SES
	FROM_ADDR = ENV.fetch("FROM_ADDR_EMAIL", "productsupport@nycopportunity.nyc.gov")

	def initialize(client: nil)
		if client.nil?
			@client = Aws::SES::Client.new(
	            region: 'us-east-1', 
	            access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
	            secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
	            session_token: ENV.fetch("AWS_SESSION_TOKEN")
	        )
	    else
	    	@client = client
	    end
	end

	def get_msg(subject, textbody, htmlbody, recipient, attachments, sendername)
		# Create a MIME Multipart Mixed object. This object will contain the body of the
		# email and the attachment.
		msg_mixed = MIME::Multipart::Mixed.new

		# Create a MIME Multipart Alternative object. This object will contain both the
		# HTML and plain text versions of the email.
		msg_body = MIME::Multipart::Alternative.new

		# Add the plain text and HTML content to the Multipart Alternative part.
		msg_body.add(MIME::Text.new(textbody,'plain'))
		msg_body.add(MIME::Text.new(htmlbody,'html'))

		# Add the Multipart Alternative part to the Multipart Mixed part.
		msg_mixed.add(msg_body)

		if !attachments.nil?
			attachments.each do |a|
				# Create a new MIME text object that contains the base64-encoded content of the
				# file that will be attached to the message.
				file = MIME::Application.new(Base64::encode64(open(a,"rb").read))

				# Specify that the file is a base64-encoded attachment to ensure that the 
				# receiving client handles it correctly. 
				file.transfer_encoding = 'base64'
				file.disposition = 'attachment'

				# Add the attachment to the Multipart Mixed part.
				msg_mixed.attach(file, 'filename' => a)
			end
		end

		# Create a new Mail object that contains the entire Multipart Mixed object. 
		# This object also contains the message headers.
		msg = MIME::Mail.new(msg_mixed)
		msg.to = { recipient => nil }
		msg.from = { FROM_ADDR => sendername }
		msg.subject = subject
		msg
	end


	def send(subject, textbody, htmlbody, recipient, attachments: nil, sendername: nil)
		# Try to send the email.
		# begin

		# Provide the contents of the email.
		resp = @client.send_raw_email({
		  raw_message: {
		    data: get_msg(subject, textbody, htmlbody, recipient, attachments, sendername).to_s
		  }
		})

		# If the message was not sent, show a message explaining what went wrong.
		# rescue Aws::SES::Errors::ServiceError => error
		#   Logger.error("Document receipt email not sent. Error message: #{error}")
		# end
	end
end