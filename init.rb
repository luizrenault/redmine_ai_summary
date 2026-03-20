require 'redmine'

require_relative 'lib/redmine_ai_summary/logger'
require_relative 'lib/redmine_ai_summary/ai_client'
require_relative 'lib/redmine_ai_summary/connection_tester'
require_relative 'lib/redmine_ai_summary/issue_patch'

Rails.configuration.to_prepare do
  require_dependency File.expand_path('app/helpers/ai_summary_settings_helper', __dir__)

  unless ActionView::Base.included_modules.include?(AiSummarySettingsHelper)
    ActionView::Base.send(:include, AiSummarySettingsHelper)
  end
end

Redmine::Plugin.register :redmine_ai_summary do
  name 'Redmine AI Summary'
  author 'Luiz + ChatGPT'
  description 'Gera resumo automático por IA e grava em campo personalizado'
  version '2.0.0'
  url 'https://example.com'
  author_url 'https://example.com'

  settings default: {
    'enabled' => '1',
    'provider' => 'ollama',
    'endpoint_url' => 'http://127.0.0.1:11434',
    'model' => 'llama3.1:8b',
    'api_key' => '',
    'custom_field_id' => '',
    'max_chars' => '500',
    'include_journals' => '1',
    'overwrite_existing' => '1',
    'trigger_on_create' => '1',
    'trigger_on_update' => '1',
    'ignored_prop_keys' => 'done_ratio,assigned_to_id,updated_on',
    'log_level' => 'info',
    'prompt_template' => <<~PROMPT
      Você é um assistente que resume tarefas do Redmine.

      Gere um resumo em português do Brasil com no máximo %{max_chars} caracteres.
      O resumo deve:
      - descrever objetivo, estado atual e próximos passos, se houver
      - ser claro e técnico
      - não inventar informações
      - não usar markdown
      - não ultrapassar %{max_chars} caracteres

      Conteúdo da tarefa:
      %{issue_text}
    PROMPT
  }, partial: 'settings/redmine_ai_summary_settings'
end