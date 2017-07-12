class MultipleProviderUser < ActiveRecord::Base
  include DeviseTokenAuth::Concerns::User

  scope :test_scope, -> { where.not(nickname: nil) }

  multiple_providers_association :authentications

  has_many :authentications, foreign_key: :user_id
end