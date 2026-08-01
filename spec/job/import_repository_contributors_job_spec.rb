# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportRepositoryContributorsJob, type: :job do
  describe '#perform' do
    it 'calls GithubContributorsImporter with the correct repository' do
      repository = create(:repository)

      expect(GithubContributorsImporter).to receive(:call).with(repository)

      described_class.new.perform(repository.id)
    end
  end
end
