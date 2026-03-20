require 'net/http'
require 'uri'
require 'json'

module RedmineAiSummary
  class ConnectionTester
    class << self
      def test(settings = nil)
        settings ||= Setting.plugin_redmine_ai_summary || {}
        provider = settings['provider'].to_s

        case provider
        when 'ollama'
          test_ollama(settings)
        when 'openai_compatible'
          test_openai_compatible(settings)
        else
          {
            success: false,
            message: "Provider não suportado: #{provider}"
          }
        end
      rescue => e
        {
          success: false,
          message: "#{e.class}: #{e.message}"
        }
      end

      private

      def test_ollama(settings)
        base = ensure_trailing_slash(settings['endpoint_url'])
        uri = URI.join(base, 'api/tags')

        res = Net::HTTP.get_response(uri)
        if res.is_a?(Net::HTTPSuccess)
          {
            success: true,
            message: 'Conexão com Ollama OK.'
          }
        else
          {
            success: false,
            message: "Erro HTTP #{res.code}: #{res.body}"
          }
        end
      end

      def test_openai_compatible(settings)
        base = ensure_trailing_slash(settings['endpoint_url'])
        path = base.end_with?('/v1/') ? 'models' : 'v1/models'
        uri = URI.join(base, path)

        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "Bearer #{settings['api_key']}" if settings['api_key'].to_s.strip != ''
        req['Content-Type'] = 'application/json'

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 10
        http.read_timeout = 30

        res = http.request(req)

        if res.is_a?(Net::HTTPSuccess)
          {
            success: true,
            message: 'Conexão com endpoint OpenAI-compatible OK.'
          }
        else
          {
            success: false,
            message: "Erro HTTP #{res.code}: #{res.body}"
          }
        end
      end

      def ensure_trailing_slash(url)
        url.to_s.end_with?('/') ? url.to_s : "#{url}/"
      end
    end
  end
end