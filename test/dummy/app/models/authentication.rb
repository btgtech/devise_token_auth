class Authentication < ActiveRecord::Base
  belongs_to :user, class_name: MultipleProviderUser
end