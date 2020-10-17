class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # https://stackoverflow.com/questions/33941864/rails-automatically-update-csrf-token-for-repeat-json-request
  # callback to set CSRF TOKEN for non-idempotent Ajax request
  after_action :add_csrf_token_to_json_request_header

  private

  def add_csrf_token_to_json_request_header
    if request.xhr? && !request.get? && protect_against_forgery?
      response.headers['X-CSRF-Token'] = form_authenticity_token
    end
  end
end
