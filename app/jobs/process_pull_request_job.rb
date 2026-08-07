# frozen_string_literal: true

class ProcessPullRequestJob < ApplicationJob
  queue_as :default

  def perform(repository_id, payload, access_token)
    PullRequestProcessor.call(repository_id, payload, access_token)
  end
end
