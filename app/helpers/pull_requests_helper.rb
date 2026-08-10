# frozen_string_literal: true

module PullRequestsHelper
  STATE_BADGE_CLASSES = {
    'open' => 'bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300',
    'merged' => 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300',
    'closed' => 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-400'
  }.freeze

  def pull_request_state_badge_classes(state)
    STATE_BADGE_CLASSES[state]
  end
end
