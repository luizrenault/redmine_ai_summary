# app/jobs/ai_summary_job.rb
class AiSummaryJob < ActiveJob::Base
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(issue_id)
    issue = Issue.find(issue_id)

    Thread.current[:ai_summary_running] = true

    settings = Setting.plugin_redmine_ai_summary
    cf_id = settings['custom_field_id'].to_i
    max_chars = settings['max_chars'].to_i

    cf = IssueCustomField.find_by(id: cf_id)
    return unless cf

    text = build_issue_text(issue, cf_id)
    return if text.blank?

    summary = RedmineAiSummary::AiClient.generate_summary(
      issue_text: text,
      max_chars: max_chars
    )

    return if summary.blank?

    issue.init_journal(User.system, "Resumo IA atualizado")

    issue.custom_field_values = {
      cf_id.to_s => summary
    }

    issue.save!(validate: false)

    RedmineAiSummary::Logger.info("Resumo atualizado issue ##{issue.id}")
  ensure
    Thread.current[:ai_summary_running] = false
  end

  def build_issue_text(issue, summary_cf_id)
    parts = []
    parts << issue.subject if issue.subject
    parts << issue.description if issue.description

    issue.custom_field_values.each do |cf|
      next if cf.custom_field.id == summary_cf_id
      parts << "#{cf.custom_field.name}: #{cf.value}"
    end

    issue.journals.each do |j|
      parts << j.notes if j.notes.present?
    end

    parts.compact.join("\n")
  end
end