module Admin
  module Users
    class Create
      def initialize(attributes)
        @attributes = attributes
      end

      def call
        user = User.new(attributes)
        CreateUserResultData.new(user: user, success: user.save)
      end

      private

      attr_reader :attributes
    end
  end
end
