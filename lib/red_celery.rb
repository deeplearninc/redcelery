require 'bunny'
require 'json'
require 'msgpack'
require 'securerandom'
require 'yaml'

require 'red_celery/config'
require 'red_celery/version'

module RedCelery
  class << self
    attr_accessor :config

    def config
      @config ||= RedCelery::Config.new
    end

    # Gets called within the initializer
    def setup
      yield(config)
    end
  end

  class Client
    VHOST_NOT_FOUND_MATCHER = /vhost .* not found/i

    Error = Class.new(StandardError)
    VhostNotFoundError = Class.new(Error)

    attr_reader :connection

    def initialize(broker_url: nil, **options)
      @connection = Bunny.new(broker_url || RedCelery.config.amqp, **options)
      @connection.start
      # http://rubybunny.info/articles/concurrency.html#sharing_channels_between_threads
      @channels = Concurrent::Hash.new
      @exchanges = Concurrent::Hash.new { |h, k| h[k] = Concurrent::Hash.new }
      @lock = Mutex.new
    rescue Bunny::NotAllowedError => e
      if e.message =~ VHOST_NOT_FOUND_MATCHER
        raise VhostNotFoundError
      else
        raise
      end
    end

    def purge_queue(queue)
      get_channel.queue_purge(queue || RedCelery.config.default_queue)
    rescue Bunny::NotFound
      false
    end

    def get_channel
      if !@channels[Thread.current]&.open?
        @channels[Thread.current] = connection.create_channel
      end

      @channels[Thread.current]
    end

    def declare_queue(name, **attrs)
      get_channel.queue(name, attrs)
    end

    def get_exchange(queue)
      channel = get_channel
      @exchanges[channel][queue] ||= channel.direct(queue, durable: true)
    end

    def send_task(task_name, queue: nil, queue_opts: {}, args: [], kwargs: {}, task_id: nil, reply_to: nil)
      task_id ||= SecureRandom.uuid
      queue ||= RedCelery.config.default_queue

      if queue == 'celery'
        queue_opts = queue_opts.merge(durable: true)
      end

      channel = get_channel

      body = {
        task: task_name,
        id: task_id,
        args: args,
        kwargs: kwargs,
      }

      @lock.synchronize do
        channel.queue(queue, **queue_opts).publish(
          body.to_json,
          {
            # content_encoding: 'binary',
            # Use JSON because by default Celery threats msgpack as a dangerous and ignore such messages
            content_type: 'application/json',
            correlation_id: task_id,
            routing_key: queue,
            reply_to: reply_to,
          }
        )
      end


      task_id
    end

    # Pull task result
    def get_task_result(task_id, result_queue = nil)
      queue = get_result_queue(result_queue || task_id)

      if queue.message_count > 0
        _delivery_info, properties, payload = queue.pop
        decode_payload(properties, payload)
      end
    end

    def get_result_queue(queue_name = nil)
      # if !@rpc_mode
      #   queue_name = queue_name.gsub('-', '')
      # end

      get_channel.queue(
        queue_name,
        auto_delete: true,
        durable: true,
        arguments: { 'x-expires' => RedCelery.config.response_queue_expiration_ms }
      )
    end

    def revoke_task(task_id, terminate: true, signal: 'TERM')
      exchange = get_channel.fanout('celery.pidbox')

      message = {
        method: 'revoke',
        arguments: {
          task_id: task_id,
          terminate: terminate,
          signal: signal
        },
      }

      @lock.synchronize do
        exchange.publish(
          message.to_json,
          {
            # content_encoding: 'binary',
            # Use JSON because by default Celery threats msgpack as a dangerous and ignore such messages
            content_type: 'application/json',
            correlation_id: task_id,
            reply_to: task_id,
          }
        )
      end
    end

    def decode_payload(properties, payload)
      case (content_type = properties[:content_type])
      when 'application/json' then JSON.parse(payload, symbolize_names: true)
      when 'application/x-yaml' then JSON.parse(payload, symbolize_names: true)
      when 'application/x-msgpack' then MessagePack.unpack(payload)
      else raise ArgumentError, "content_type '#{content_type}' isn't supported"
      end
    end

    def close
      @channels.clear
      @exchanges.clear
      connection.close
    end
  end
end
