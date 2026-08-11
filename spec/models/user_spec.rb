# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe 'associations' do
    it { is_expected.to have_many(:repositories) }
    it { is_expected.to have_one(:configuration).dependent(:destroy) }
  end

  describe 'validations' do
    it 'is invalid without an email' do
      user = build(:user, email: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('no puede estar en blanco')
    end

    it 'is invalid with a duplicate email' do
      create(:user, email: 'taken@example.com')
      user = build(:user, email: 'taken@example.com')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('ya está en uso')
    end

    it 'is invalid with a duplicate email regardless of case' do
      create(:user, email: 'taken@example.com')
      user = build(:user, email: 'TAKEN@example.com')

      expect(user).not_to be_valid
    end

    it 'is invalid with a malformed email' do
      user = build(:user, email: 'not-an-email')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('no es válido')
    end

    it 'is invalid without a password' do
      user = build(:user, password: nil)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('no puede estar en blanco')
    end

    it 'is invalid with a password shorter than 6 characters' do
      user = build(:user, password: '12345')

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('es demasiado corto (6 caracteres mínimo)')
    end
  end
end
