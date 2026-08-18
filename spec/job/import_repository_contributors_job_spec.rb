# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryContributorsJob, type: :job do
  describe '#perform' do
    it 'calls GithubContributorsImporter with the repository' do
      repository = create(:repository, provider: 'github')

      expect(Github::GithubContributorsImporter).to receive(:call).with(repository)

      described_class.new.perform(repository.id)
    end

    it 'calls GitlabContributorsImporter with the repository' do
      repository = create(:repository, provider: 'gitlab')

      expect(Gitlab::GitlabContributorsImporter).to receive(:call).with(repository)

      described_class.new.perform(repository.id)
    end
  end
end
