require 'date'
require 'mysql2'

require './src/logger'

class MySQL
    SECS_PER_DAY = 60*60*24
    INSERT_SUBMISSION = "INSERT INTO submission (type, has_email) VALUES ('%s', %s)"
    LAST_DAY = "SELECT * FROM submission WHERE created_at BETWEEN '#{(Time.now - (SECS_PER_DAY)).strftime("%Y-%m-%d")}' AND '#{Time.now.strftime("%Y-%m-%d")}'"

    def initialize(client: nil)
        if not client.nil?
            @client = client

        elsif ENV.fetch("TENANCY") == "local"
            @client = Mysql2::Client.new(
                :host => ENV.fetch("LOCAL_DB_HOSTNAME"), 
                :username => ENV.fetch("LOCAL_DB_USERNAME"),
                :password => ENV.fetch("LOCAL_DB_PW"),
                :database => ENV.fetch("LOCAL_DB_NAME"),
                :reconnect => true
            )
        else
            @client = Mysql2::Client.new(
                :host => ENV.fetch("DB_HOSTNAME"), 
                :username => ENV.fetch("DB_USERNAME"),
                :password => ENV.fetch("DB_PW"),
                :database => ENV.fetch("DB_NAME"),
                :reconnect => true
            )
        end
    end

    def add_submission(type, has_email)
        @client.query(INSERT_SUBMISSION % [type, has_email ? 1 : 0])
    end

    def get_last_day()
        @client.query(LAST_DAY)
    end
end
