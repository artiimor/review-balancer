# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileExtensionMapping do
  describe 'validations' do
    subject { build(:file_extension_mapping) }

    it { is_expected.to validate_presence_of(:extension) }
    it { is_expected.to validate_uniqueness_of(:extension) }
    it { is_expected.to validate_presence_of(:tech) }
  end
end
