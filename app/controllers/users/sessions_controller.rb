# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout false

  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      sign_in(resource_name, resource)
      current_user.create_or_update_track_file!(code_text: params[:file_text])
      render(json: {}, status: 200)
    else
      render(json: 'wrong email or password'.to_json, status: :unauthorized)
    end
  end

  # DELETE /resource/sign_out
  def destroy
    super
  end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
