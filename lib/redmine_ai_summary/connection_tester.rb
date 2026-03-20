# lib/redmine_ai_summary/connection_tester.rb
module RedmineAiSummary
  class ConnectionTester
    def self.test!
      s = Setting.plugin_redmine_ai_summary
      url = s['endpoint_url']

      uri = URI("#{url}/api/tags")
      res = Net::HTTP.get_response(uri)

      res.is_a?(Net::HTTPSuccess)
    end
  end
end