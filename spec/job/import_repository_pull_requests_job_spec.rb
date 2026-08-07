# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryPullRequestsJob, type: :job do
  describe '#perform' do
    it 'calls GithubPullRequestsImporter with the correct repository and access token' do
      repository = create(:repository, provider: 'github')

      expect(Github::GithubPullRequestsImporter).to receive(:call).with(repository, 'ghp_test_token')

      described_class.new.perform(repository.id, 'ghp_test_token')
    end

    it 'calls GitlabPullRequestsImporter with the correct repository and access token' do
      repository = create(:repository, provider: 'gitlab')

      expect(Gitlab::GitlabPullRequestsImporter).to receive(:call).with(repository, 'glpat_test_token')

      described_class.new.perform(repository.id, 'glpat_test_token')
    end
  end
end
