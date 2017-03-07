class MultipleProviderUser < ActiveRecord::Base
  include DeviseTokenAuth::Concerns::User

  multiple_providers_association :authentications

  has_many :authentications, foreign_key: :user_id
end