module RedCelery
  class Config
    # See http://rubybunny.info/articles/connecting.html
    # includes :host, :port, :ssl, :vhost, :user, :pass, :heartbeat, :frame_max, :auth_mechanism
    attr_accessor :amqp

    attr_accessor :exchange, :key, :results

    def initialize
      @amqp = {}
      @exchange = 'celery'
      @key = 'celery'
      @results = 'celeryresults'
    end
  end
end
