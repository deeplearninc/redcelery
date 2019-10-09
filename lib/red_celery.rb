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

    def initialize(broker_url = nil)
      @conn = Bunny.new(broker_url || RedCelery.config.amqp)
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

      if block
        result_queue = task_id_to_queue(task_id)
        result_queue.subscribe do |delivery_info, properties, payload|
          block.call(decode_payload(properties, payload))
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
          payload: decode_payload(properties, payload)
        }
      end
    end

    def revoke_task(task_id, terminate: true, signal: 'TERM')
      # queue =
      exchange = channel.fanout('celery.pidbox')

      message = {
        method: 'revoke',
        arguments: {
          task_id: task_id,
          terminate: terminate,
          signal: signal
        },
        # destination: nil,
      }

      # {
      #   "method": "revoke",
      #   "arguments": {
      #     "task_id": "0748dd5c-02a6-4441-852f-5b000b954e6a",
      #     "terminate": true,
      #     "signal": null
      #   },
      #   "destination": null,
      #   "pattern": null,
      #   "matcher": null
      # }

      exchange.publish(
        message.to_json,
        {
          # content_encoding: 'binary',
          # Use JSON because by default Celery threats msgpack as a dangerous and ignore such messages
          content_type: 'application/json',
          correlation_id: task_id,
          reply_to: task_id,
          # routing_key: queue,
        }
      )
    end

    def task_id_to_queue(task_id)
      channel.queue(task_id, auto_delete: true)
    end

    def decode_payload(properties, payload)
      case (content_type = properties[:content_type])
      when 'application/json' then JSON.parse(payload)
      when 'application/x-yaml' then JSON.parse(payload)
      when 'application/x-msgpack' then MessagePack.unpack(payload)
      else raise ArgumentError, "content_type '#{content_type}' isn't supported"
      end
    end

    def close
      conn.close
    end
  end
end
