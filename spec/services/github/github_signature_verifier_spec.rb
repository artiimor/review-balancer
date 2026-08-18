# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Github::GithubSignatureVerifier do
  let(:secret) { 'test-secret' }
  let(:body) { '{"action":"opened"}' }

  def signature_for(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, body)}"
  end

  it 'accepts a signature correctly computed with the correct secret' do
    valid_signature = signature_for(body, secret)

    expect(
      described_class.valid?(payload_body: body, signature_header: valid_signature, secret: secret)
    ).to eq(true)
  end

  it 'rejects a signature computed with a different secret' do
    wrong_signature = signature_for(body, 'otro-secreto')

    expect(
      described_class.valid?(payload_body: body, signature_header: wrong_signature, secret: secret)
    ).to eq(false)
  end

  it 'rejects if there is no signature header' do
    expect(
      described_class.valid?(payload_body: body, signature_header: nil, secret: secret)
    ).to eq(false)
  end

  it 'rejects if the payload body has been tampered with' do
    valid_signature = signature_for(body, secret)
    tampered_body = '{"action":"closed"}'

    expect(
      described_class.valid?(payload_body: tampered_body, signature_header: valid_signature, secret: secret)
    ).to eq(false)
  end
end
