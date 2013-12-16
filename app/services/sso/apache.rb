require 'iconv' if RUBY_VERSION.start_with?('1.8.')

module SSO
  class Apache < Base
    delegate :session, :to => :controller

    CAS_USERNAME = 'REMOTE_USER'
    ENV_TO_ATTR_MAPPING = {
        'REMOTE_USER_EMAIL'     => :mail,
        'REMOTE_USER_FIRSTNAME' => :firstname,
        'REMOTE_USER_LASTNAME'  => :lastname,
    }

    def available?
      return false unless Setting['authorize_login_delegation']
      return false if controller.api_request? and not Setting['authorize_login_delegation_api']
      return false if controller.api_request? and not request.env[CAS_USERNAME].present?
      true
    end

    def support_expiration?
      true
    end

    def support_fallback?
      true
    end

    # If REMOTE_USER is provided by the web server then
    # authenticate the user without using password.
    def authenticated?
      return false unless (self.user = request.env[CAS_USERNAME])
      attrs = { :login => self.user }.merge(additional_attributes)
      return false unless User.find_or_create_external_user(attrs, Setting['authorize_login_delegation_auth_source_user_autocreate'])
      store
      true
    end

    def support_login?
      request.fullpath != self.login_url
    end

    def authenticate!
      self.has_rendered = true
      controller.redirect_to controller.extlogin_users_path
    end

    def login_url
      controller.extlogin_users_path
    end

    def logout_url
      Setting['login_delegation_logout_url'] || controller.extlogout_users_path
    end

    def expiration_url
      controller.extlogin_users_path
    end

    private

    def additional_attributes
      attrs = {}
      ENV_TO_ATTR_MAPPING.each do |header, attribute|
        if request.env.has_key?(header)
          value = request.env[header].dup
          value = convert_encoding(value) unless value.valid_encoding?
          attrs[attribute] = value
        end
      end
      attrs
    end

    def convert_encoding(value)
      if value.respond_to?(:force_encoding)
        value.encode(Encoding::UTF_8, Encoding::ISO_8859_1, { :invalid => :replace, :replace => '-' }).force_encoding(Encoding::UTF_8)
      else
        Iconv.new('UTF-8//IGNORE', 'UTF-8').iconv(value) rescue value
      end
    end

    def store
      session[:sso_method] = self.class.to_s
    end

  end
end
