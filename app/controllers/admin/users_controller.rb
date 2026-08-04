class Admin::UsersController < AdminController
  def index
    @users = User.order(:created_at)
  end

  def new
    @user = User.new
  end

  def create
    result = Admin::Users::Create.new(user_params).call
    @user = result.user

    if result.success?
      redirect_to admin_users_path, notice: "User created. They can now connect their Jellyfin account."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: %i[email_address password password_confirmation])
  end
end
