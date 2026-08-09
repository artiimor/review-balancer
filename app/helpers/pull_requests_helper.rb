# frozen_string_literal: true

module PullRequestsHelper
  STATE_BADGE_CLASSES = {
    'open' => 'bg-amber-50 text-amber-700',
    'merged' => 'bg-emerald-50 text-emerald-700',
    'closed' => 'bg-slate-100 text-slate-500'
  }.freeze

  def pull_request_state_badge_classes(state)
    STATE_BADGE_CLASSES[state]
  end
end
