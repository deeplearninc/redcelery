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
    attr_reader :conn, :channel

    def initialize(broker_url: nil, &task_done_callback)
      @conn = Bunny.new(broker_url || RedCelery.config.amqp)
      conn.start
      @channel = conn.create_channel
      @exchanges = {}
      @task_done_callback = task_done_callback
      @result_queue = "celery.results.#{SecureRandom.uuid}"

      subscribe(@result_queue, task_done_callback)
    end

    def get_exchange(queue)
      @exchanges[queue] ||= channel.direct(
        queue,
        durable: true
      )
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

      exchange.publish(
        body.to_json,
        {
          # content_encoding: 'binary',
          # Use JSON because by default Celery threats msgpack as a dangerous and ignore such messages
          content_type: 'application/json',
          correlation_id: task_id,
          reply_to: @task_done_callback ? @result_queue : task_id,
          routing_key: queue,
        }
      )

      task_id
    end

    def subscribe(task_id, block)
      get_result_queue(task_id).subscribe do |_delivery_info, properties, payload|
        block.call(decode_payload(properties, payload))
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
      exchange = channel.fanout('celery.pidbox')

      message = {
        method: 'revoke',
        arguments: {
          task_id: task_id,
          terminate: terminate,
          signal: signal
        },
      }

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

    def get_result_queue(queue_name = nil)
      channel.queue(queue_name, auto_delete: true)
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
      conn.close
    end
  end
end
