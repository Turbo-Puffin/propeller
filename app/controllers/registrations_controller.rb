class RegistrationsController < ApplicationController
  def new
    redirect_to "/dashboard" if logged_in?
  end

  def create
    account = Account.new(
      name: params[:account_name],
      subdomain: params[:account_name]&.parameterize,
      plan: :free,
      status: :active
    )

    user = account.users.build(
      name: params[:name],
      email: params[:email]&.downcase&.strip,
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      role: :owner
    )

    if account.save
      session[:user_id] = user.id
      redirect_to "/dashboard", notice: "Welcome to Propeller, #{user.name}!"
    else
      @errors = account.errors.full_messages + user.errors.full_messages
      flash.now[:alert] = @errors.first
      render :new, status: :unprocessable_entity
    end
  end
end
