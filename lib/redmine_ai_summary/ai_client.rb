require 'net/http'
require 'uri'
require 'json'

module RedmineAiSummary
  class AiClient
    class << self
      def generate_summary(issue_text:, max_chars:)
        settings = Setting.plugin_redmine_ai_summary || {}
        provider = settings['provider'].to_s
        prompt_template = settings['prompt_template'].to_s

        if prompt_template.strip.empty?
          prompt_template = <<~PROMPT
            Você é um assistente que resume tarefas do Redmine.

            Gere um resumo em português do Brasil com no máximo %{max_chars} caracteres.
            O resumo deve:
            - descrever objetivo, estado atual e próximos passos
            - ser claro e técnico
            - não inventar informações
            - não usar markdown

            Conteúdo da tarefa:
            %{issue_text}
          PROMPT
        end

        prompt = format(
          prompt_template,
          issue_text: issue_text,
          max_chars: max_chars
        )

        response_text =
          case provider
          when 'ollama'
            call_ollama(
              endpoint_url: settings['endpoint_url'],
              model: settings['model'],
              prompt: prompt
            )
          when 'openai_compatible'
            call_openai_compatible(
              endpoint_url: settings['endpoint_url'],
              model: settings['model'],
              api_key: settings['api_key'],
              prompt: prompt
            )
          else
            raise "Provider não suportado: #{provider}"
          end

        normalize_and_truncate(response_text, 2*max_chars)
      end

      private

      def call_ollama(endpoint_url:, model:, prompt:)
        base = ensure_trailing_slash(endpoint_url)
        uri = URI.join(base, 'api/generate')

        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req.body = {
          model: model,
          prompt: prompt,
          stream: false,
          options: {
            temperature: 0.2
          }
        }.to_json

        res = perform_http(uri, req)
        json = JSON.parse(res.body)
        text =
          json['response'] ||
          json.dig('message', 'content') ||
          json.dig('choices', 0, 'message', 'content') ||
          'No content.'

        text.to_s.strip
      end

      def call_openai_compatible(endpoint_url:, model:, api_key:, prompt:)
        base = ensure_trailing_slash(endpoint_url)
        path = base.end_with?('/v1/') ? 'chat/completions' : 'v1/chat/completions'
        uri = URI.join(base, path)

        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req['Authorization'] = "Bearer #{api_key}" if api_key.to_s.strip != ''
        req.body = {
          model: model,
          messages: [
            {
              role: 'system',
              content: 'Você resume tarefas do Redmine em pt-BR, com objetividade, clareza e sem inventar informações.'
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          temperature: 0.2
        }.to_json

        res = perform_http(uri, req)
        json = JSON.parse(res.body)
        json.dig('choices', 0, 'message', 'content').to_s
      end

      def perform_http(uri, req)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 15
        http.read_timeout = 120

        res = http.request(req)

        unless res.is_a?(Net::HTTPSuccess)
          raise "Erro HTTP #{res.code}: #{res.body}"
        end

        res
      end

      def ensure_trailing_slash(url)
        url.to_s.end_with?('/') ? url.to_s : "#{url}/"
      end

      def normalize_and_truncate(text, max_chars)
        txt = text.to_s.gsub(/\s+/, ' ').strip
        return txt if txt.length <= max_chars

        cut = txt[0, max_chars - 1].rstrip
        last_space = cut.rindex(' ')
        cut = cut[0, last_space].rstrip if last_space && last_space > (max_chars * 0.6)
        "#{cut}…"
      end
    end
  end
end