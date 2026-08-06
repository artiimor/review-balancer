# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryContributorsJob, type: :job do
  describe '#perform' do
    it 'calls GithubContributorsImporter with the correct repository and access token' do
      repository = create(:repository)

      expect(Github::GithubContributorsImporter).to receive(:call).with(repository, 'ghp_test_token')

      described_class.new.perform(repository.id, 'ghp_test_token')
    end
  end
end
