require 'test_helper'

class ApplicationsControllerTest < ActionController::TestCase
  describe DeviseTokenAuth::ApplicationController do
    setup do
      @request.env['devise.mapping'] = Devise.mappings[:mang]
      DeviseTokenAuth.resource_class_scope = :custom_scope
    end

    teardown do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      DeviseTokenAuth.resource_class_scope = nil
    end

    test 'returns the scoped resource' do
      assert_equal Mang::ActiveRecord_Relation, @controller.send(:scoped_resource_class).class
    end

    test 'returns false if the omniauth provider is not scoped' do
      assert_equal false, @controller.send(:scoped_omniauth_provider?, 'non_existing_provider')
    end

    test 'returns true if the omniauth provider is scoped' do
      DeviseTokenAuth.scoped_omniauth_providers = ['existing_provider']
      assert_equal true, @controller.send(:scoped_omniauth_provider?, 'existing_provider')
    end
  end
end