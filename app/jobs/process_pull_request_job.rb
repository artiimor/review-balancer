# frozen_string_literal: true

class ProcessPullRequestJob < ApplicationJob
  queue_as :default

  def perform(repository_id, payload, github_access_token)
    PullRequestProcessor.call(repository_id, payload, github_access_token)
  end
end
