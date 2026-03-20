module RedmineAiSummary
  module IssuePatch
    def self.included(base)
      base.class_eval do
        after_commit :enqueue_ai_summary_on_create, on: :create
        after_commit :enqueue_ai_summary_on_update, on: :update
      end
    end

    def enqueue_ai_summary_on_create
      settings = Setting.plugin_redmine_ai_summary || {}
      return unless settings['enabled'].to_s == '1'
      return unless settings['trigger_on_create'].to_s == '1'
      return if Thread.current[:redmine_ai_summary_updating]

      RedmineAiSummary::Logger.info("Enfileirando resumo para issue ##{id} após criação")
      AiSummaryJob.perform_later(id)
    rescue => e
      RedmineAiSummary::Logger.error("Erro ao enfileirar resumo na criação da issue ##{id}: #{e.class} - #{e.message}")
    end

    def enqueue_ai_summary_on_update
      settings = Setting.plugin_redmine_ai_summary || {}
      return unless settings['enabled'].to_s == '1'
      return unless settings['trigger_on_update'].to_s == '1'
      return if Thread.current[:redmine_ai_summary_updating]
      return unless ai_summary_relevant_change?
      return if ai_summary_only_summary_field_changed?

      RedmineAiSummary::Logger.info("Enfileirando resumo para issue ##{id} após atualização")
      AiSummaryJob.perform_later(id)
    rescue => e
      RedmineAiSummary::Logger.error("Erro ao enfileirar resumo na atualização da issue ##{id}: #{e.class} - #{e.message}")
    end

    private

    def ai_summary_relevant_change?
      journal = journals.reorder(:id).last
      return true unless journal

      details = journal.details.to_a
      return true if details.empty?

      ignored = ai_summary_ignored_prop_keys

      details.any? do |detail|
        prop_key = detail.prop_key.to_s
        property = detail.property.to_s

        if property == 'cf'
          true
        else
          !ignored.include?(prop_key)
        end
      end
    end

    def ai_summary_only_summary_field_changed?
      journal = journals.reorder(:id).last
      return false unless journal

      details = journal.details.to_a
      return false if details.empty?

      summary_cf = ai_summary_custom_field
      return false unless summary_cf

      details.all? do |detail|
        detail.property.to_s == 'cf' && detail.prop_key.to_s == summary_cf.id.to_s
      end
    end

    def ai_summary_custom_field
      cf_id = (Setting.plugin_redmine_ai_summary || {})['custom_field_id'].to_i
      return nil if cf_id <= 0

      IssueCustomField.find_by(id: cf_id)
    end

    def ai_summary_ignored_prop_keys
      raw = (Setting.plugin_redmine_ai_summary || {})['ignored_prop_keys'].to_s
      raw.split(',').map { |v| v.strip }.reject(&:blank?)
    end
  end
end

unless Issue.included_modules.include?(RedmineAiSummary::IssuePatch)
  Issue.send(:include, RedmineAiSummary::IssuePatch)
end