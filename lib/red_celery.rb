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

    def initialize
      @conn = Bunny.new(RedCelery.config.amqp.compact)
      conn.start
      @channel = conn.create_channel
      @exchanges = {}
    end

    def get_exchange(queue)
      @exchanges[queue] ||= channel.direct(
        queue,
        durable: true
      )
    end

    # block - optional callback with result of task
    def send_task(task_name, queue: nil, task_args: [], task_kwargs: {}, task_id: nil, &block)
      task_id ||= SecureRandom.uuid

      queue ||= RedCelery.config.default_queue
      exchange = get_exchange(queue)

      body = {
        task: task_name,
        id: task_id,
        args: task_args,
        kwargs: task_kwargs,
      }

      if block
        result_queue = task_id_to_queue(task_id)
        result_queue.subscribe do |delivery_info, properties, payload|
          message =
            case (content_type = properties[:content_type])
            when 'application/json' then JSON.parse(payload)
            when 'application/x-yaml' then JSON.parse(payload)
            when 'application/x-msgpack' then MessagePack.unpack(payload)
            else raise ArgumentError, "content_type '#{content_type}' isn't supported"
            end

          block.call(message)
        end
      end

      exchange.publish(
        body.to_json,
        {
          # content_encoding: 'binary',
          # Use JSON because by default Celery threats msgpack as a dangerous and ignore such messages
          content_type: 'application/json',
          correlation_id: task_id,
          reply_to: task_id,
          routing_key: queue,
        }
      )

      task_id
    end

    # Pull task result
    def get_task_result(task_id)
      queue = task_id_to_queue(task_id)

      if queue.message_count > 0
        delivery_info, properties, payload = queue.pop

        {
          delivery_info: delivery_info,
          properties: properties,
          payload: payload
        }
      end
    end

    def task_id_to_queue(task_id)
      channel.queue(task_id, auto_delete: true)
    end

    def close
      conn.close
    end
  end
end
