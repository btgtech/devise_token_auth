module DeviseTokenAuth
  class PasswordsController < DeviseTokenAuth::ApplicationController
    before_action :set_user_by_token, :only => [:update]
    skip_after_action :update_auth_header, :only => [:create, :edit]

    # this action is responsible for generating password reset tokens and
    # sending emails
    def create
      unless resource_params[:email]
        return render_create_error_missing_email
      end

      # give redirect value from params priority
      @redirect_url = params[:redirect_url]

      # fall back to default value if provided
      @redirect_url ||= DeviseTokenAuth.default_password_reset_url

      unless @redirect_url
        return render_create_error_missing_redirect_url
      end

      # if whitelist is set, validate redirect_url against whitelist
      if DeviseTokenAuth.redirect_whitelist
        unless DeviseTokenAuth.redirect_whitelist.include?(@redirect_url)
          return render_create_error_not_allowed_redirect_url
        end
      end

      # honor devise configuration for case_insensitive_keys
      if resource_class.case_insensitive_keys.include?(:email)
        @email = resource_params[:email].downcase
      else
        @email = resource_params[:email]
      end

      if resource_class.multiple_providers
        q = 'email = ?'
      else
        q = "uid = ? AND provider='email'"

        # fix for mysql default case insensitivity
        if ActiveRecord::Base.connection.adapter_name.downcase.starts_with? 'mysql'
          q = "BINARY uid = ? AND provider='email'"
        end
      end

      @resource = resource_class.where(q, @email).first

      @errors = nil
      @error_status = 400

      # Cannot generate a reset password token if the user doesn't have a password set
      if @resource && @resource.encrypted_password.blank?
        return render_create_error
      end

      if @resource
        yield @resource if block_given?
        reset_password_attrs = {
          email: @email,
          redirect_url: @redirect_url,
          client_config: params[:config_name]
        }

        reset_password_attrs.merge!(provider: 'email') unless resource_class.multiple_providers

        @resource.send_reset_password_instructions(reset_password_attrs)

        if @resource.errors.empty?
          return render_create_success
        else
          @errors = @resource.errors
        end
      else
        @errors = [I18n.t("devise_token_auth.passwords.user_not_found", email: @email)]
        @error_status = 404
      end

      if @errors
        return render_create_error
      end
    end

    # this is where users arrive after visiting the password reset confirmation link
    def edit
      reset_password_token = Devise.token_generator.digest(self, :reset_password_token, resource_params[:reset_password_token])
      @resource = resource_class.find_by_reset_password_token(reset_password_token)
      # previous validation to check that the token exists and is valid before doing the password reset
      if @resource && @resource.reset_password_period_valid?
        # finds or initializes a resource by token with other possible errors
        @resource = resource_class.reset_password_by_token({
          reset_password_token: resource_params[:reset_password_token]
        })

        if @resource and @resource.id
          client_id  = SecureRandom.urlsafe_base64(nil, false)
          token      = SecureRandom.urlsafe_base64(nil, false)
          token_hash = BCrypt::Password.create(token)
          expiry     = (Time.now + DeviseTokenAuth.token_lifespan).to_i

          @resource.tokens[client_id] = {
            token:  token_hash,
            expiry: expiry
          }

          # ensure that user is confirmed
          @resource.skip_confirmation! if @resource.devise_modules.include?(:confirmable) && !@resource.confirmed_at

          # allow user to change password once without current_password
          @resource.allow_password_change = true

          @resource.save!
          yield @resource if block_given?

          render_edit_success(token, client_id, expiry)
        else
          render_edit_error
        end
      else
        render_edit_error_invalid
      end
    end

    def update
      # make sure user is authorized
      unless @resource
        return render_update_error_unauthorized
      end

      # make sure account doesn't use oauth2 provider
      # support multiple providers
      unless resource_class.multiple_providers || @resource.provider == 'email'
        return render_update_error_password_not_required
      end

      # ensure that password params were sent
      unless password_resource_params[:password] and password_resource_params[:password_confirmation]
        return render_update_error_missing_password
      end

      if @resource.send(resource_update_method, password_resource_params)
        @resource.allow_password_change = false

        yield @resource if block_given?
        return render_update_success
      else
        return render_update_error
      end
    end

    protected

    def resource_update_method
      if DeviseTokenAuth.check_current_password_before_update == false or @resource.allow_password_change == true
        "update_attributes"
      else
        "update_with_password"
      end
    end

    def render_create_error_missing_email
      render json: {
        success: false,
        errors: [I18n.t("devise_token_auth.passwords.missing_email")]
      }, status: 401
    end

    def render_create_error_missing_redirect_url
      render json: {
        success: false,
        errors: [I18n.t("devise_token_auth.passwords.missing_redirect_url")]
      }, status: 401
    end

    def render_create_error_not_allowed_redirect_url
      render json: {
        status: 'error',
        data:   resource_data,
        errors: [I18n.t("devise_token_auth.passwords.not_allowed_redirect_url", redirect_url: @redirect_url)]
      }, status: 422
    end

    def render_create_success
      render json: {
        success: true,
        data: resource_data,
        message: I18n.t("devise_token_auth.passwords.sended", email: @email)
      }
    end

    def render_create_error
      render json: {
        success: false,
        errors: @errors,
      }, status: @error_status
    end

    def render_edit_success(token, client_id, expiry)
      render json: {
        success: true,
        data: resource_data,
        reset_password: true,
        token: token,
        client_id: client_id,
        expiry: expiry
      }
    end

    def render_edit_error
      render json: {
        success: false,
        errors: ['Not Found']
      }, status: 404
    end

    def render_edit_error_invalid
      render json: {
        success: false,
        errors: ['Reset password token is invalid']
      }, status: 401
    end

    def render_update_error_unauthorized
      render json: {
        success: false,
        errors: ['Unauthorized']
      }, status: 401
    end

    def render_update_error_password_not_required
      render json: {
        success: false,
        errors: [I18n.t("devise_token_auth.passwords.password_not_required", provider: @resource.provider.humanize)]
      }, status: 422
    end

    def render_update_error_missing_password
      render json: {
        success: false,
        errors: [I18n.t("devise_token_auth.passwords.missing_passwords")]
      }, status: 422
    end

    def render_update_success
      render json: {
        success: true,
        data: resource_data,
        message: I18n.t("devise_token_auth.passwords.successfully_updated")
      }
    end

    def render_update_error
      return render json: {
        success: false,
        errors: resource_errors
      }, status: 422
    end

    private

    def resource_params
      params.permit(:email, :password, :password_confirmation, :current_password, :reset_password_token)
    end

    def password_resource_params
      params.permit(*params_for_resource(:account_update))
    end

  end
end
