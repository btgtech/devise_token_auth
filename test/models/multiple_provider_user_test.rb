require 'test_helper'

class MultipleProviderUserTest < ActiveSupport::TestCase
  describe MultipleProviderUser do
    test 'uid and provider are disable' do
      user = MultipleProviderUser.new
      refute user.respond_to?(:uid)
      refute user.respond_to?(:provider)
      assert user.respond_to?(:email)
    end

    test 'it has a multiple provider association' do
      assert MultipleProviderUser.multiple_providers
      assert_equal MultipleProviderUser.multiple_providers_association, :authentications
    end

    test 'multiple providers association responds to uid and provider' do
      user = MultipleProviderUser.new
      association = user.authentications.build
      assert association.respond_to?(:uid)
      assert association.respond_to?(:provider)
    end
  end
end
