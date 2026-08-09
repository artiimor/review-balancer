# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryPullRequestsJob, type: :job do
  describe '#perform' do
    it 'calls GithubPullRequestsImporter with the repository, access token and configured lookback' do
      repository = create(:repository, provider: 'github')
      repository.user.configuration.update!(lookback_months: 5)

      expect(Github::GithubPullRequestsImporter).to receive(:call)
        .with(repository, 'ghp_test_token', lookback: 5.months)

      described_class.new.perform(repository.id, 'ghp_test_token')
    end

    it 'calls GitlabPullRequestsImporter with the repository, access token and configured lookback' do
      repository = create(:repository, provider: 'gitlab')
      repository.user.configuration.update!(lookback_months: 5)

      expect(Gitlab::GitlabPullRequestsImporter).to receive(:call)
        .with(repository, 'glpat_test_token', lookback: 5.months)

      described_class.new.perform(repository.id, 'glpat_test_token')
    end

    it 'falls back to the importer default when the owner has no configuration' do
      repository = create(:repository, provider: 'github')
      repository.user.configuration.destroy

      expect(Github::GithubPullRequestsImporter).to receive(:call).with(repository, 'ghp_test_token')

      described_class.new.perform(repository.id, 'ghp_test_token')
    end
  end
end
