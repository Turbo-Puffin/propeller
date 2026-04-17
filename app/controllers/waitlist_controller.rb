class WaitlistController < ApplicationController
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  def create
    email = params[:email]
    source = params[:source]
    entry = WaitlistEntry.find_or_initialize_by(email: email.to_s.downcase.strip)
    entry.source ||= source if source.present?

    if entry.save
      respond_to do |format|
        format.json { render json: { ok: true }, status: :created }
        format.html do
          flash[:notice] = "You're on the list! We'll be in touch soon."
          redirect_to root_path(anchor: "waitlist")
        end
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, error: entry.errors.full_messages.first }, status: :unprocessable_entity }
        format.html do
          flash[:alert] = entry.errors.full_messages.first || "Something went wrong. Please try again."
          redirect_to root_path(anchor: "waitlist")
        end
      end
    end
  end
end
