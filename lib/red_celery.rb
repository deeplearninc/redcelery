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
        key: queue,
        durable: true
      )
    end

    def send_task(queue, task_name, task_args: [], task_kwargs: {}, task_id: nil, &block)
      task_id ||= SecureRandom.uuid
      exchange = get_exchange(queue)

      body = {
        task: task_name,
        id: task_id,
        args: task_args,
        kwargs: task_kwargs,
      }

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
        # result_queue.delete
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

          # application_headers: {
          #   lang: 'py',
          #   task: task_name,
          #   id: task_id,
          #   # 'root_id': uuid root_id,
          #   # 'parent_id': uuid parent_id,
          #   # 'group': uuid group_id,
          #   retries: retries,
          #   eta: eta,
          #   expires: expires
          # }
        }
      )
    end

    def task_id_to_queue(task_id)
      channel.queue(task_id, auto_delete: true)
    end

    def close
      # @exchanges.each { |_, e| e.delete }
      conn.close
    end
  end
end
