class WaitlistController < ApplicationController
  def create
    entry = WaitlistEntry.new(email: params[:email])

    if entry.save
      flash[:notice] = "You're on the list! We'll be in touch soon."
    else
      flash[:alert] = entry.errors.full_messages.first || "Something went wrong. Please try again."
    end

    redirect_to root_path(anchor: "waitlist")
  end
end
