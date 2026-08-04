module Admin
  module Users
    CreateUserResultData = Data.define(:user, :success) do
      def success?
        success
      end
    end
  end
end
