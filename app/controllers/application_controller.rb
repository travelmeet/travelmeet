class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to main_app.root_path, :alert => exception.message
  end

  def after_sign_in_path_for(resource)
    if resource.is_profile_completed
      session.delete("user_return_to") || root_path
    else
      me_edit_path
    end
  end

  def after_sign_out_path_for(resource)
    root_path
  end

end
