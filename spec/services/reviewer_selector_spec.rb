# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewerSelector do
  let(:user) { User.create!(email: 'user@example.com', password: 'password123') }
  let(:repository) do
    Repository.create!(github_full_name: 'arturo/demo', webhook_secret: 's3cr3t', user: user, provider: 'github')
  end
  let(:author) { Contributor.create!(github_login: 'autora-pr') }
  let(:experta_ruby) { Contributor.create!(github_login: 'experta-ruby') }
  let(:experta_saturada) { Contributor.create!(github_login: 'experta-saturada') }
  let(:novato) { Contributor.create!(github_login: 'novato') }

  def merged_pr_touching(contributor, tech, lines:, days_ago: 1)
    pr = PullRequest.create!(
      repository: repository, author: contributor, github_number: rand(1..999_999),
      opened_at: (days_ago + 1).days.ago, merged_at: days_ago.days.ago, state: 'merged'
    )
    FileChange.create!(pull_request: pr, contributor: contributor, path: 'x.rb', tech: tech, lines_changed: lines)
    pr
  end

  def open_pr_touching(tech)
    PullRequest.create!(
      repository: repository, author: author, github_number: rand(1..999_999),
      opened_at: 1.hour.ago, state: 'open'
    ).tap do |pr|
      FileChange.create!(pull_request: pr, contributor: author, path: 'y.rb', tech: tech, lines_changed: 10)
    end
  end

  before do
    Configuration.create!(user: user, lookback_months: 1,
                          github_access_token: 'gh-token', gitlab_access_token: 'gl-token')

    # Todos han contribuido antes al repo (para aparecer como candidatos).
    merged_pr_touching(experta_ruby, 'Ruby', lines: 500)
    merged_pr_touching(experta_saturada, 'Ruby', lines: 800)
    merged_pr_touching(novato, 'Ruby', lines: 5)

    allow_any_instance_of(Octokit::Client).to receive(:request_pull_request_review)
  end

  it 'prioriza a quien más sabe de la tecnología tocada, entre los candidatos con carga similar' do
    pr = open_pr_touching('Ruby')

    ranked = described_class.rank(pr, top_n: 3)
    top_choice = ranked.first[:contributor]

    expect(top_choice).to eq(experta_saturada).or eq(experta_ruby)
    expect(ranked.first[:score]).to be > ranked.last[:score]
  end

  it 'penaliza a un experto saturado frente a alguien con menos carga aunque sepa algo menos' do
    pr = open_pr_touching('Ruby')

    # Saturamos a experta_saturada con 5 revisiones pendientes.
    5.times do
      ReviewAssignment.create!(pull_request: pr, reviewer: experta_saturada, assigned_at: Time.current)
    end

    ranked = described_class.rank(pr, top_n: 3)
    top_choice = ranked.first[:contributor]

    expect(top_choice).to eq(experta_ruby)
  end

  it 'nunca elige al autor de la PR como su propio revisor' do
    pr = open_pr_touching('Ruby')

    ranked = described_class.rank(pr, top_n: 10)

    expect(ranked.map { |r| r[:contributor] }).not_to include(author)
  end

  it 'assign! crea el ReviewAssignment con el mejor candidato' do
    pr = open_pr_touching('Ruby')

    assignment = described_class.assign!(pr)

    expect(assignment).to be_persisted
    expect(assignment.pull_request).to eq(pr)
  end

  it 'assign! no completa la asignación si la PR sigue abierta' do
    pr = open_pr_touching('Ruby')

    assignment = described_class.assign!(pr)

    expect(assignment.completed_at).to be_nil
  end

  it 'assign! completa la asignación al momento si la PR ya está cerrada (webhook desordenado o reintento tardío)' do
    pr = open_pr_touching('Ruby')
    pr.update!(state: 'merged', merged_at: Time.current)

    assignment = described_class.assign!(pr)

    expect(assignment.completed_at).not_to be_nil
  end

  it 'matched_tech_for devuelve nil si el mejor candidato no tiene expertise en las techs tocadas' do
    pr = open_pr_touching('JavaScript/Frontend')

    assignment = described_class.assign!(pr)

    expect(assignment.matched_tech).to be_nil
  end

  it 'no elige como candidato a quien está de vacaciones ahora mismo' do
    create(:holiday, contributor: experta_ruby, start_date: 1.day.ago, end_date: 1.day.from_now)
    pr = open_pr_touching('Ruby')

    candidates = described_class.candidates_for(pr)

    expect(candidates).not_to include(experta_ruby)
  end

  it 'sigue considerando candidato a quien tiene unas vacaciones pasadas o futuras' do
    create(:holiday, contributor: experta_ruby, start_date: 10.days.ago, end_date: 5.days.ago)
    create(:holiday, contributor: experta_ruby, start_date: 5.days.from_now, end_date: 10.days.from_now)
    pr = open_pr_touching('Ruby')

    candidates = described_class.candidates_for(pr)

    expect(candidates).to include(experta_ruby)
  end

  it 'assign! does not assign a contributor who is in vacation' do
    create(:holiday, contributor: experta_ruby, start_date: 1.day.ago, end_date: 1.day.from_now)
    create(:holiday, contributor: experta_saturada, start_date: 1.day.ago, end_date: 1.day.from_now)
    pr = open_pr_touching('Ruby')

    assignment = described_class.assign!(pr)

    expect(assignment.reviewer).to eq(novato)
  end

  it 'assign! does not assign a contributor who is deactivated' do
    repository.repository_contributors.find_by!(contributor: experta_ruby).update!(active: false)
    repository.repository_contributors.find_by!(contributor: experta_saturada).update!(active: false)
    pr = open_pr_touching('Ruby')

    assignment = described_class.assign!(pr)

    expect(assignment.reviewer).to eq(novato)
  end

  it 'assign! requests the review in GitHub using the token from the configuration' do
    pr = open_pr_touching('Ruby')

    expect(Octokit::Client).to receive(:new).with(access_token: 'gh-token').and_call_original

    described_class.assign!(pr)
  end

  it 'assign! sets the reviewer in GitLab using the token from the configuration when the repository is on GitLab' do
    repository.update!(provider: 'gitlab')
    pr = open_pr_touching('Ruby')
    gitlab_client = instance_double(Gitlab::Client, users: [double(id: 99)], update_merge_request: true)

    expect(Gitlab).to receive(:client)
      .with(endpoint: 'https://gitlab.com/api/v4', private_token: 'gl-token')
      .and_return(gitlab_client)

    assignment = described_class.assign!(pr)

    expect(gitlab_client).to have_received(:users).with(username: assignment.reviewer.github_login)
    expect(gitlab_client).to have_received(:update_merge_request)
      .with(repository.github_full_name, pr.github_number, reviewer_ids: [99])
  end

  it 'assign! returns nil if there is no candidates' do
    solo_repo = Repository.create!(github_full_name: 'arturo/solo-repo', webhook_secret: 's3cr3t', user: user)
    pr = PullRequest.create!(
      repository: solo_repo, author: author, github_number: rand(1..999_999),
      opened_at: 1.hour.ago, state: 'open'
    )

    assignment = described_class.assign!(pr)

    expect(assignment).to be_nil
  end
end
