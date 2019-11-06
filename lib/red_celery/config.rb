module RedCelery
  class Config
    # See http://rubybunny.info/articles/connecting.html
    # includes :host, :port, :ssl, :vhost, :user, :pass, :heartbeat, :frame_max, :auth_mechanism
    attr_accessor :amqp
    attr_accessor :default_queue, :rpc_mode, :amqp_borker_url, :response_queue_expiration_sec

    def initialize
      @amqp = {
        host: ENV['REDCELERY_HOST'],
        user: ENV['REDCELERY_USER'],
        vhost: ENV['REDCELERY_VHOST'],
        pass: ENV['REDCELERY_PASS'],
      }.compact

      @amqp_borker_url = ENV['REDCELERY_BROKER_URL']

      @default_queue = 'celery'
      @rpc_mode = true
      @response_queue_expiration_sec = 3600
    end

    def amqp
      @amqp_borker_url || @amqp
    end

    def response_queue_expiration_ms
      response_queue_expiration_sec * 1000
    end
  end
end
