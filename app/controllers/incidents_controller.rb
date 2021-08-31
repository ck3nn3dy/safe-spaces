class IncidentsController < ApplicationController
  before_action :set_incident, only: %i[show edit call]
  skip_before_action :authenticate_user!, only: [ :connect ]
  skip_forgery_protection
  skip_after_action :verify_authorized, only: [ :connect ]

  def new
    @incident = Incident.new
    authorize @incident
  end

  def create
    @incident = Incident.new(incident_params)
    @incident.user = current_user
    @space = Space.near([params[:lat], params[:lng]], 100).where(available: true).reject do |space|
      current_user.spaces.find do |user_space|
        space == user_space
      end
    end.first || Space.first
    authorize @incident
    @incident.space = @space

    if @incident.save
      @notification = CommentNotification.with(incident: @incident)
      @notification.deliver(@space.user)
      redirect_to incident_path(@incident, lng: params[:lng], lat: params[:lat])
    end
  end


  def show
    @user = @incident.user
    # @space = @incident.space
    @space = @incident.space
    @markers = [
      {
        lat: @incident.space.latitude,
        lng: @incident.space.longitude,
        # infoWindow: { content: render_to_string(partial: "/spaces/info_window", locals: { space: @space }) },
        image_url: helpers.asset_url(Cloudinary::Utils.cloudinary_url(@space.user.photo.key))
      }
    ]
    @usermarker = [{ image_url: helpers.asset_url(Cloudinary::Utils.cloudinary_url(@user.photo.key))}]
    @message = Message.new
  end

  def edit
  end

  def update
    if @incident.update(incident_params)
      redirect_to edit_incident_path(@incident)
    else
      render :show
    end
  end

  def call
    if @incident.space.user == current_user
      TwilioService.new(@incident.user.phone_num).call
    else
      TwilioService.new(@incident.space.user.phone_num).call
    end
  end

  def connect
    response = Twilio::TwiML::VoiceResponse.new do |r|
      r.say(message: 'One moment please.', voice: 'alice')
      r.dial number: params[:phone_number]
    end
    render xml: response.to_s
  end

  private

  def set_incident
    @incident = Incident.find(params[:id])
    authorize @incident
  end

  def incident_params
    params.require(:incident).permit(:safe_status, :arrived)
  end
end
