module AiSummarySettingsHelper
  def ai_summary_issue_custom_field_options
    IssueCustomField.order(:name).map { |cf| [cf.name, cf.id] }
  end

  def ai_summary_provider_options
    [
      ['Ollama', 'ollama'],
      ['OpenAI compatible', 'openai_compatible']
    ]
  end

  def ai_summary_log_level_options
    [
      ['Debug', 'debug'],
      ['Info', 'info'],
      ['Warn', 'warn'],
      ['Error', 'error']
    ]
  end

  def ai_summary_checked?(settings, key)
    settings[key].to_s == '1'
  end

  def ai_summary_selected_custom_field(settings)
    settings['custom_field_id'].to_s
  end
end