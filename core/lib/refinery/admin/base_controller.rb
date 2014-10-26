require 'action_controller'

module Refinery
  module Admin
    module BaseController

      def self.included(base)
        base.layout :layout?

        base.before_action :force_ssl!,
                           :authenticate_refinery_user!,
                           :restrict_controller

        base.after_action :store_location?, :only => [:index] # for redirect_back_or_default

        base.helper_method :searching?, :group_by_date
      end

      def admin?
        true # we're in the admin base controller, so always true.
      end

      def searching?
        params[:search].present?
      end

      protected

      def force_ssl!
        redirect_to :protocol => 'https' if Refinery::Core.force_ssl && !request.ssl?
      end

      def authenticate_refinery_user!
        ::Zilch::AuthorisationManager.instance.authenticate!
      end

      def group_by_date(records)
        new_records = []

        records.each do |record|
          key = record.created_at.strftime("%Y-%m-%d")
          # TODO: Shadowing outer variable
          record_group = new_records.collect{|records| records.last if records.first == key }.flatten.compact << record
          (new_records.delete_if {|i| i.first == key}) << [key, record_group]
        end

        new_records
      end

      def restrict_controller
        unless allow_controller? params[:controller].gsub 'admin/', ''
          logger.warn "'#{current_refinery_user}' tried to access '#{params[:controller]}' but was rejected."
          error_404
        end
      end

      private

      def allow_controller?(controller_path)
        ::Zilch::AuthorisationManager.instance.allow_access_to_controller?(controller_path)
      end

      def layout?
        "refinery/admin#{'_dialog' if from_dialog?}"
      end

      # TODO: all store_location stuff should be in its own object..
      # Check whether it makes sense to return the user to the last page they
      # were at instead of the default e.g. refinery_admin_pages_path
      # right now we just want to snap back to index actions and definitely not to dialogues.
      def store_location?
        store_location unless request.xhr? || from_dialog?
      end

      # Store the URI of the current request in the session.
      #
      # We can return to this location by calling #redirect_back_or_default.
      def store_location
        session[:return_to] = request.fullpath
      end

      # Clear and return the stored location
      def pop_stored_location
        session.delete(:return_to)
      end

      # Redirect to the URI stored by the most recent store_location call or
      # to the passed default.
      def redirect_back_or_default(default)
        redirect_to(pop_stored_location || default)
      end


      # Override authorized? so that only users with the Refinery role can admin the website.
      # def authorized?
      #   refinery_user?
      # end


      # def refinery_user?
      #   auth_manager = Refinery::AuthenticationManager.instance
      #   auth_manager.authenticated? && auth_manager.
      #     Zilch::AuthorisationManager.instance.current_user.has_role?(:refinery)
    end
  end
end
