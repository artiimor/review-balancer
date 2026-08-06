# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gitlab::GitlabContributorsImporter do
  describe '.call' do
    let(:repository) { create(:repository, github_full_name: 'acme/checkout-api', provider: 'gitlab') }
    let(:gitlab_access_token) { 'fake_token' }

    def gitlab_member(username)
      double(username: username)
    end

    def stub_team_members(*usernames)
      members = usernames.map { |username| gitlab_member(username) }
      paginated = double
      allow(paginated).to receive(:auto_paginate) { |&block| members.each(&block) }
      allow_any_instance_of(Gitlab::Client).to receive(:team_members)
        .with(repository.github_full_name)
        .and_return(paginated)
    end

    it 'creates a Contributor for each member returned by the GitLab API' do
      stub_team_members('alice', 'bob')

      expect { described_class.call(repository, gitlab_access_token) }.to change(Contributor, :count).by(2)
      expect(Contributor.pluck(:github_login)).to contain_exactly('alice', 'bob')
    end

    it 'links each contributor to the repository via RepositoryContributor' do
      stub_team_members('alice')

      described_class.call(repository, gitlab_access_token)

      contributor = Contributor.find_by(github_login: 'alice')
      expect(repository.repository_contributors.pluck(:contributor_id)).to contain_exactly(contributor.id)
    end

    it 'reuses an existing Contributor by github_login instead of duplicating it' do
      existing = create(:contributor, github_login: 'alice')
      stub_team_members('alice')

      expect { described_class.call(repository, gitlab_access_token) }.not_to change(Contributor, :count)
      expect(repository.repository_contributors.pluck(:contributor_id)).to contain_exactly(existing.id)
    end

    it 'is idempotent if the contributor is already linked to the repository' do
      contributor = create(:contributor, github_login: 'alice')
      create(:repository_contributor, repository: repository, contributor: contributor)
      stub_team_members('alice')

      expect { described_class.call(repository, gitlab_access_token) }.not_to change(RepositoryContributor, :count)
    end
  end
end
