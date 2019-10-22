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

    def initialize(broker_url: nil, rpc_mode: nil, &task_done_callback)
      @connection = Bunny.new(broker_url || RedCelery.config.amqp)
      @connection.start
      # http://rubybunny.info/articles/concurrency.html#sharing_channels_between_threads
      @channels = Concurrent::Hash.new
      @exchanges = Concurrent::Hash.new { |h, k| h[k] = Concurrent::Hash.new }
      @lock = Mutex.new

      @rpc_mode = rpc_mode != nil ? rpc_mode : RedCelery.config.rpc_mode
      @task_done_callback = task_done_callback

      if @task_done_callback && @rpc_mode
        @result_queue = "celery.results.#{SecureRandom.uuid}"
        subscribe(@result_queue, task_done_callback)
      end
    rescue Bunny::NotAllowedError => e
      if e.message =~ VHOST_NOT_FOUND_MATCHER
        raise VhostNotFoundError
      else
        raise
      end
    end

    def get_channel
      @channels[Thread.current] ||= connection.create_channel
    end

    def get_exchange(queue)
      channel = get_channel
      @exchanges[channel][queue] ||= channel.direct(queue, durable: true)
    end

    # block - optional callback with result of task
    def send_task(task_name, queue: nil, args: [], kwargs: {}, task_id: nil, &block)
      task_id ||= SecureRandom.uuid
      queue ||= RedCelery.config.default_queue

      exchange = get_exchange(queue)

      body = {
        task: task_name,
        id: task_id,
        args: args,
        kwargs: kwargs,
      }

      if block && !@task_done_callback
        subscribe(task_id, block)
      end

      if @rpc_mode != true && @task_done_callback
        subscribe(task_id, @task_done_callback)
      end

      @lock.synchronize do
        exchange.publish(
          body.to_json,
          {
            # content_encoding: 'binary',
            # Use JSON because by default Celery threats msgpack as a dangerous and ignore such messages
            content_type: 'application/json',
            correlation_id: task_id,
            reply_to: (@task_done_callback && @rpc_mode ? @result_queue : task_id),
            routing_key: queue,
          }
        )
      end


      task_id
    end

    def subscribe(task_id, block)
      @lock.synchronize do
        get_result_queue(task_id).subscribe do |_delivery_info, properties, payload|
          block.call(decode_payload(properties, payload))
        end
      end
    end

    # Pull task result
    def get_task_result(task_id)
      queue = get_result_queue(task_id)

      if queue.message_count > 0
        _delivery_info, properties, payload = queue.pop
        decode_payload(properties, payload)
      end
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

    def get_result_queue(queue_name = nil)
      if !@rpc_mode
        queue_name = queue_name.gsub('-', '')
      end

      get_channel.queue(queue_name, auto_delete: true, durable: true, arguments: { 'x-expires' => 3600000 })
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
