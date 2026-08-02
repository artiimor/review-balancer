# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe 'associations' do
    it 'has many repositories' do
      user = create(:user)
      repository = create(:repository, user: user)

      expect(user.repositories).to contain_exactly(repository)
    end
  end

  describe 'validations' do
    it 'is invalid without an email' do
      user = build(:user, email: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'is invalid with a duplicate email' do
      create(:user, email: 'taken@example.com')
      user = build(:user, email: 'taken@example.com')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'is invalid with a duplicate email regardless of case' do
      create(:user, email: 'taken@example.com')
      user = build(:user, email: 'TAKEN@example.com')

      expect(user).not_to be_valid
    end

    it 'is invalid with a malformed email' do
      user = build(:user, email: 'not-an-email')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'is invalid without a password' do
      user = build(:user, password: nil)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'is invalid with a password shorter than 6 characters' do
      user = build(:user, password: '12345')

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end
  end
end
