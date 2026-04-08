class SessionsController < ApplicationController
  def new
    redirect_to "/dashboard" if logged_in?
  end

  def create
    user = User.find_by(email: params[:email]&.downcase&.strip)

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to "/dashboard", notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    @current_user = nil
    redirect_to root_path, notice: "You've been logged out."
  end
end
