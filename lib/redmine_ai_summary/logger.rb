module RedmineAiSummary
  class Logger
    class << self
      def debug(message)
        log(:debug, message)
      end

      def info(message)
        log(:info, message)
      end

      def warn(message)
        log(:warn, message)
      end

      def error(message)
        log(:error, message)
      end

      private

      def log(level, message)
        configured = configured_level
        return unless allowed?(level, configured)

        Rails.logger.public_send(level, "[redmine_ai_summary] #{message}")
      rescue => e
        Rails.logger.error("[redmine_ai_summary] Falha no logger: #{e.class} - #{e.message}")
      end

      def configured_level
        raw = Setting.plugin_redmine_ai_summary['log_level'].to_s.presence || 'info'
        normalize_level(raw)
      rescue
        :info
      end

      def normalize_level(level)
        case level.to_s
        when 'debug' then :debug
        when 'info'  then :info
        when 'warn'  then :warn
        when 'error' then :error
        else :info
        end
      end

      def allowed?(current, configured)
        order = {
          debug: 0,
          info:  1,
          warn:  2,
          error: 3
        }
        order[current] >= order[configured]
      end
    end
  end
end