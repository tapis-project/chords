class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, except: :bulk_create

  before_action :set_global, :set_access_control_header

  before_action :set_params_from_json_api_spec!
  before_action :set_json_api_spec_reponse_headers!
  
  before_action :authenticate_user_from_token!
  before_action :authenticate_user!

  def set_access_control_header
    headers['Access-Control-Allow-Origin'] = '*'
  end

  def set_global
    ActionMailer::Base.default_url_options = {:host => request.host_with_port}

    notavailmsg = "unknown"
    @chords_release  = ENV.fetch('DOCKER_TAG'           , notavailmsg)
    @source_revision = ENV.fetch('CHORDS_GIT_SHA'       , notavailmsg) [0..6]
    @source_branch   = ENV.fetch('CHORDS_GIT_BRANCH'    , notavailmsg)
    @build_time      = ENV.fetch('CHORDS_BUILD_TIME'    , notavailmsg)
    @kernel_release  = ENV.fetch('CHORDS_KERNEL_RELEASE', notavailmsg)
    @kernel_version  = ENV.fetch('CHORDS_KERNEL_VERSION', notavailmsg)
    @machine         = ENV.fetch('CHORDS_MACHINE'       , notavailmsg)
    @rails_env       = Rails.env
    @rails_version   = Rails::VERSION::STRING
    @system_uptime   = ApplicationHelper.system_uptime
    @server_uptime   = ApplicationHelper.server_uptime

    if !(@profile = Profile.first)
      Profile.initialize
      @profile = Profile.first
    end

    if @profile.logo != nil
      @logo_base64 = @profile.logo
    else
      @logo_base64 = nil
    end

    # TODO: find a way to avoid doing this
    if !Site.first
      Site.initialize
    end

    # TODO: find a way to avoid doing this
    if !Instrument.first
      Instrument.initialize
    end

    # ALWAYS require a user to be logged in and be an administrator in order to edit anything
    # TODO: 'secure administration' should evetually be removed from the profile model entirely
    @profile.secure_administration = true
  end

private

  def authenticate_user!(*args)
    current_user.present? || super(*args)
  end

  def authenticate_user_from_token!
    email = params[:email].presence
    user = email && User.find_by_email(email)

    api_key = if params[:api_key]
                params[:api_key]
              else
                nil
              end

    # Devise.secure_compare used to compare the token in the database with the
    # token given in the params, mitigating timing attacks
    if user && Devise.secure_compare(user.api_key, api_key)
      sign_in user, store: false
    end
  end

  def set_params_from_json_api_spec!
    if (request.content_type == 'application/vnd.api+json')
      users_json = params[:data].select {|element| element["type"] == "users" }

      if (users_json.length == 1)
        params[:email] = users_json[0].dig(:attributes, :email) || nil
        params[:api_key] = users_json[0].dig(:attributes, :api_key) || nil
      end

    end
  end

  def set_json_api_spec_reponse_headers!
    if (request.content_type == 'application/vnd.api+json')
      # https://blog.codeship.com/the-json-api-spec/
      # Automaticall set the correct response headers if this is part of the JSON:API spec
      api_mime_types = %W(
        application/vnd.api+json
        text/x-json
        application/json
      )
      Mime::Type.register 'application/vnd.api+json', :json, api_mime_types
    end
  end

  def current_user
    if super
      user = super
    else
      user = User.new
      user.roles = [:guest]
    end

    user
  end

  # Access denied redirect
  rescue_from "CanCan::AccessDenied" do |exception|
    respond_to do |format|
      format.html { redirect_to '/about', alert: "You don't have permission to access this page. Do you need to sign in?" }
      format.sensorml { head :forbidden, content_type: 'text/sensorml' }
      format.json { render json: { errors: ['Access Denied, user authentication required.'] }, status: :forbidden }
      format.geojson { render json: { errors: ['Access Denied, user authentication required.'] }, status: :forbidden }
      format.js { head :forbidden, content_type: 'text/js' }
      format.csv { head :forbidden, content_type: 'text/csv' }
      format.xml { head :forbidden, content_type: 'text/xml' }
    end
  end

  rescue_from "Net::SMTPAuthenticationError" do |exception|
    flash[:alert] = "Cannot send email, please contact the site administrator at: #{Profile.first.try(:contact_email)}"
    Rails.logger.warn(exception)
    redirect_to about_index_url
  end
end
