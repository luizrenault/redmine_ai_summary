class AiSummarySettingsController < ApplicationController
  layout 'admin'
  before_action :require_admin

  def test_connection
    result = RedmineAiSummary::ConnectionTester.test(merged_settings_from_params)
    render json: result
  rescue => e
    render json: {
      success: false,
      message: "#{e.class}: #{e.message}"
    }, status: 500
  end

  private

  def merged_settings_from_params
    current = (Setting.plugin_redmine_ai_summary || {}).dup
    incoming = params.fetch(:settings, {}).to_unsafe_h rescue {}
    current.merge(incoming)
  end
end