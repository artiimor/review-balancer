# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gitlab::GitlabSignatureVerifier do
  let(:secret) { 'test-secret' }

  it 'accepts when the header token matches the secret' do
    expect(
      described_class.valid?(token_header: secret, secret: secret)
    ).to eq(true)
  end

  it 'rejects when the header token does not match the secret' do
    expect(
      described_class.valid?(token_header: 'otro-secreto', secret: secret)
    ).to eq(false)
  end

  it 'rejects if there is no token in the header' do
    expect(
      described_class.valid?(token_header: nil, secret: secret)
    ).to eq(false)
  end

  it 'rejects if the header is an empty string' do
    expect(
      described_class.valid?(token_header: '', secret: secret)
    ).to eq(false)
  end
end
