class Mang < ActiveRecord::Base
  include DeviseTokenAuth::Concerns::User
  scope :custom_scope , -> { where('1 = 1') }
end
