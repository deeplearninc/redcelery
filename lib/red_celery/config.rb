module RedCelery
  class Config
    # See http://rubybunny.info/articles/connecting.html
    # includes :host, :port, :ssl, :vhost, :user, :pass, :heartbeat, :frame_max, :auth_mechanism
    attr_accessor :amqp

    attr_accessor :default_queue

    def initialize
      @amqp = {
        host: ENV['REDCELERY_HOST'],
        user: ENV['REDCELERY_USER'],
        vhost: ENV['REDCELERY_VHOST'],
        pass: ENV['REDCELERY_PASS'],
      }.compact

      @default_queue = 'celery'
    end
  end
end
