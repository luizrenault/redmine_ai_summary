# lib/redmine_ai_summary/issue_patch.rb
module RedmineAiSummary
  module IssuePatch
    def self.included(base)
      base.class_eval do
        after_commit :enqueue_ai_summary, on: [:create, :update]
      end
    end

    def enqueue_ai_summary
      return unless Setting.plugin_redmine_ai_summary['enabled'] == '1'
      return if Thread.current[:ai_summary_running]

      # Só dispara se houve mudança relevante
      return unless ai_summary_relevant_change?

      RedmineAiSummary::Logger.info("Enfileirando resumo para issue ##{id}")
      AiSummaryJob.perform_later(self.id)
    end

    def ai_summary_relevant_change?
      journal = journals.last
      return true unless journal

      ignored = ['done_ratio', 'assigned_to_id']

      journal.details.any? do |d|
        !ignored.include?(d.prop_key)
      end
    end
  end
end

Issue.include RedmineAiSummary::IssuePatch