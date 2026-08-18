# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryPullRequestsJob, type: :job do
  describe '#perform' do
    it 'calls GithubPullRequestsImporter with the repository and the configured lookback' do
      repository = create(:repository, provider: 'github')
      repository.user.configuration.update!(lookback_months: 5)

      expect(Github::GithubPullRequestsImporter).to receive(:call).with(repository, lookback: 5.months)

      described_class.new.perform(repository.id)
    end

    it 'calls GitlabPullRequestsImporter with the repository and the configured lookback' do
      repository = create(:repository, provider: 'gitlab')
      repository.user.configuration.update!(lookback_months: 5)

      expect(Gitlab::GitlabPullRequestsImporter).to receive(:call).with(repository, lookback: 5.months)

      described_class.new.perform(repository.id)
    end

    it 'falls back to the importer default lookback when the owner has no configuration' do
      repository = create(:repository, provider: 'github')
      repository.user.configuration.destroy

      expect(Github::GithubPullRequestsImporter).to receive(:call).with(repository)

      described_class.new.perform(repository.id)
    end
  end
end
