# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessPullRequestJob, type: :job do
  describe '#perform' do
    it 'delega en PullRequestProcessor con repository_id y payload' do
      expect(PullRequestProcessor).to receive(:call).with(1, { 'action' => 'opened' })
      described_class.new.perform(1, { 'action' => 'opened' })
    end
  end
end
