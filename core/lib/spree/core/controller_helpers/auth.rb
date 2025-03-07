# frozen_string_literal: true

require 'cancan'

module Spree
  module Core
    module ControllerHelpers
      module Auth
        extend ActiveSupport::Concern

        # @!attribute [rw] unauthorized_redirect
        #   @!scope class
        #   Extension point for overriding behaviour of access denied errors.
        #   Default behaviour is to redirect back or to "/unauthorized" with a flash
        #   message.
        #   @return [Proc] action to take when access denied error is raised.

        included do
          before_action :set_guest_token
          helper_method :try_spree_current_user
          helper_method :spree_current_user

          class_attribute :unauthorized_redirect
          self.unauthorized_redirect = -> do
            flash[:error] = I18n.t('spree.authorization_failure')
            redirect_back(fallback_location: "/unauthorized")
          end

          rescue_from CanCan::AccessDenied do
            instance_exec(&unauthorized_redirect)
          end
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Ability.new(spree_current_user)
        end

        def redirect_back_or_default(default)
          Spree::Deprecation.warn <<~MSG
            'Please use #stored_spree_user_location_or when using solidus_auth_devise.
            Otherwise, please utilize #redirect_back provided in Rails 5+ or
            #redirect_back_or_to in Rails 7+ instead'
          MSG

          redirect_to(session["spree_user_return_to"] || default)
          session["spree_user_return_to"] = nil
        end

        def set_guest_token
          unless cookies.signed[:guest_token].present?
            cookies.permanent.signed[:guest_token] = Spree::Config[:guest_token_cookie_options].merge(
              value: SecureRandom.urlsafe_base64(nil, false),
              httponly: true
            )
          end
        end

        def store_location
          Spree::Deprecation.warn <<~MSG
            store_location is being deprecated in solidus 4.0
            without replacement
          MSG

          Spree::UserLastUrlStorer.new(self).store_location
        end

        # Auth extensions are expected to define it, otherwise it's a no-op
        def spree_current_user
          defined?(super) ? super : nil
        end

        # proxy method to *possible* spree_current_user method
        # Authentication extensions (such as spree_auth_devise) are meant to provide spree_current_user
        def try_spree_current_user
          # This one will be defined by apps looking to hook into Spree
          # As per authentication_helpers.rb
          if respond_to?(:spree_current_user, true)
            spree_current_user
          # This one will be defined by Devise
          elsif respond_to?(:current_spree_user, true)
            current_spree_user
          end
        end

        deprecate try_spree_current_user: :spree_current_user, deprecator: Spree::Deprecation
      end
    end
  end
end
