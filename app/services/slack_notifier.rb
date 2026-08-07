# frozen_string_literal: true

# Envía un mensaje a Slack cuando se asigna una revisión. Usa un bot token
# simple (chat.postMessage) — no hace falta nada más sofisticado para el MVP.
class SlackNotifier
  SLACK_API_URL = 'https://slack.com/api/chat.postMessage'

  def self.notify_review_assigned(review_assignment)
    reviewer = review_assignment.reviewer
    pr = review_assignment.pull_request

    return unless reviewer.slack_user_id.present?

    text = I18n.t('services.slack_notifier.review_assigned',
                   number: pr.github_number, title: pr.title, repository: pr.repository.github_full_name)

    connection.post do |req|
      req.body = {
        channel: reviewer.slack_user_id, # DM directo al user id
        text: text
      }.to_json
    end
  end

  def self.connection
    Faraday.new do |f|
      f.headers['Authorization'] = "Bearer #{ENV.fetch('SLACK_BOT_TOKEN')}"
      f.headers['Content-Type'] = 'application/json'
      f.url_prefix = SLACK_API_URL
      f.adapter Faraday.default_adapter
    end
  end
end
