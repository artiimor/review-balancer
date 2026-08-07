# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gitlab::GitlabSignatureVerifier do
  let(:secret) { 'test-secret' }

  it 'acepta cuando el token de la cabecera coincide con el secreto' do
    expect(
      described_class.valid?(token_header: secret, secret: secret)
    ).to eq(true)
  end

  it 'rechaza cuando el token de la cabecera no coincide con el secreto' do
    expect(
      described_class.valid?(token_header: 'otro-secreto', secret: secret)
    ).to eq(false)
  end

  it 'rechaza si no hay token en la cabecera' do
    expect(
      described_class.valid?(token_header: nil, secret: secret)
    ).to eq(false)
  end

  it 'rechaza si la cabecera es una cadena vacía' do
    expect(
      described_class.valid?(token_header: '', secret: secret)
    ).to eq(false)
  end
end
