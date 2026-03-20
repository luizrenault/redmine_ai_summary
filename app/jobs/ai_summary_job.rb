class AiSummaryJob < ActiveJob::Base
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(issue_id)
    settings = Setting.plugin_redmine_ai_summary || {}
    return unless settings['enabled'].to_s == '1'

    issue = Issue.find_by(id: issue_id)
    unless issue
      RedmineAiSummary::Logger.warn("Issue ##{issue_id} não encontrada para geração de resumo")
      return
    end

    cf = selected_custom_field(settings)
    unless cf
      RedmineAiSummary::Logger.warn("Campo customizado de resumo não configurado")
      return
    end

    max_chars = settings['max_chars'].to_i
    max_chars = 500 if max_chars <= 0

    current_value = issue.custom_field_value(cf).to_s.strip
    if current_value.present? && settings['overwrite_existing'].to_s != '1'
      RedmineAiSummary::Logger.info("Issue ##{issue.id} já possui resumo e overwrite está desativado")
      return
    end

    issue_text = build_issue_text(issue, cf.id, settings)
    if issue_text.blank?
      RedmineAiSummary::Logger.info("Issue ##{issue.id} sem conteúdo útil para resumir")
      return
    end

    summary = RedmineAiSummary::AiClient.generate_summary(
      issue_text: issue_text,
      max_chars: max_chars
    )

    if summary.to_s.strip.blank?
      RedmineAiSummary::Logger.warn("Resumo vazio retornado pela IA para issue ##{issue.id}")
      return
    end

    Thread.current[:redmine_ai_summary_updating] = true

    begin
      cv = issue.custom_values.find_by(custom_field_id: cf.id)

      if cv
        cv.update_column(:value, summary)
      else
        CustomValue.create!(
          customized: issue,
          custom_field: cf,
          value: summary
        )
      end

      RedmineAiSummary::Logger.info("Resumo atualizado silenciosamente issue ##{issue.id}")

    ensure
      Thread.current[:redmine_ai_summary_updating] = false
    end

  rescue => e
    RedmineAiSummary::Logger.error("Erro no AiSummaryJob para issue ##{issue_id}: #{e.class} - #{e.message}")
    raise
  end

  private

  def selected_custom_field(settings)
    cf_id = settings['custom_field_id'].to_i
    return nil if cf_id <= 0

    IssueCustomField.find_by(id: cf_id)
  end

  def build_issue_text(issue, summary_cf_id, settings)
    parts = []

    parts << "Assunto: #{normalize_text(issue.subject)}" if issue.subject.present?

    meta = []
    meta << "Projeto: #{issue.project.name}" if issue.project
    meta << "Tipo: #{issue.tracker.name}" if issue.tracker
    meta << "Status: #{issue.status.name}" if issue.status
    meta << "Prioridade: #{issue.priority.name}" if issue.priority
    meta << "Autor: #{issue.author.name}" if issue.author
    meta << "Responsável: #{issue.assigned_to.name}" if issue.assigned_to
    parts << meta.join(' | ') if meta.any?

    parts << "Descrição: #{normalize_text(issue.description)}" if issue.description.present?

    issue.custom_field_values.each do |cfv|
      next unless cfv.custom_field
      next if cfv.custom_field.id == summary_cf_id
      next if cfv.value.blank?

      value =
        if cfv.value.is_a?(Array)
          cfv.value.reject(&:blank?).join(', ')
        else
          cfv.value.to_s
        end

      next if value.strip.blank?

      parts << "Campo #{cfv.custom_field.name}: #{normalize_text(value)}"
    end

    if settings['include_journals'].to_s == '1'
      issue.journals.includes(:user).order(:created_on).each do |journal|
        next if journal.notes.blank?

        user_name = journal.user&.name || 'Usuário'
        parts << "Comentário de #{user_name} em #{journal.created_on}: #{normalize_text(journal.notes)}"
      end
    end

    
    parts.reject(&:blank?).join("\n")

    text = parts.join("\n").strip

    text
  end

  def normalize_text(text)
    text.to_s.gsub(/\s+/, ' ').strip
  end
end