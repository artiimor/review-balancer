# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryPullRequestsJob, type: :job do
  describe '#perform' do
    it 'calls GithubPullRequestsImporter with the correct repository' do
      repository = create(:repository)

      expect(GithubPullRequestsImporter).to receive(:call).with(repository)

      described_class.new.perform(repository.id)
    end
  end
end
