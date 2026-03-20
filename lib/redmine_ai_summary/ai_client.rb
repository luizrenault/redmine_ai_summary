# lib/redmine_ai_summary/ai_client.rb
module RedmineAiSummary
  class AiClient
    def self.generate_summary(issue_text:, max_chars:)
      s = Setting.plugin_redmine_ai_summary
      provider = s['provider']

      prompt = <<~TXT
        Resuma a tarefa abaixo em português em no máximo #{max_chars} caracteres:

        #{issue_text}
      TXT

      case provider
      when 'ollama'
        call_ollama(s['endpoint_url'], s['model'], prompt)
      else
        call_openai(s, prompt)
      end
    end

    def self.call_ollama(url, model, prompt)
      uri = URI("#{url}/api/generate")
      res = Net::HTTP.post(uri, {
        model: model,
        prompt: prompt,
        stream: false
      }.to_json, "Content-Type" => "application/json")

      JSON.parse(res.body)["response"]
    end
  end
end