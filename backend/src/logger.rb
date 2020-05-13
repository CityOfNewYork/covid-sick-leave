require 'logger'

class Logger
    def self.log
        if @logger.nil?
            @logger = Logger.new STDOUT
            @logger.level = ENV.fetch('LOG_LEVEL', Logger::INFO)
            @logger.datetime_format = '%Y-%m-%d %H:%M:%S '
        end
        @logger
    end

    def self.info(msg)
        self.log.info(msg)
    end

    def self.error(msg)
        self.log.error(msg)
    end

    def self.debug(msg)
        self.log.debug(msg)
    end

    def self.warn(msg)
        self.log.warn(msg)
    end
end