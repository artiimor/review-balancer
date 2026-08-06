# frozen_string_literal: true

class Configuration < ApplicationRecord
  belongs_to :user

  encrypts :github_access_token
  encrypts :gitlab_access_token
end
