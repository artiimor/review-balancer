# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Github::GithubSignatureVerifier do
  let(:secret) { 'test-secret' }
  let(:body) { '{"action":"opened"}' }

  def signature_for(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, body)}"
  end

  it 'acepta una firma calculada correctamente con el secreto correcto' do
    valid_signature = signature_for(body, secret)

    expect(
      described_class.valid?(payload_body: body, signature_header: valid_signature, secret: secret)
    ).to eq(true)
  end

  it 'rechaza una firma calculada con un secreto distinto' do
    wrong_signature = signature_for(body, 'otro-secreto')

    expect(
      described_class.valid?(payload_body: body, signature_header: wrong_signature, secret: secret)
    ).to eq(false)
  end

  it 'rechaza si no hay cabecera de firma' do
    expect(
      described_class.valid?(payload_body: body, signature_header: nil, secret: secret)
    ).to eq(false)
  end

  it 'rechaza si el cuerpo del payload ha sido alterado' do
    valid_signature = signature_for(body, secret)
    tampered_body = '{"action":"closed"}'

    expect(
      described_class.valid?(payload_body: tampered_body, signature_header: valid_signature, secret: secret)
    ).to eq(false)
  end
end
