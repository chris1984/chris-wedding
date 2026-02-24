Sequel.migration do
  change do
    create_table(:rsvps) do
      primary_key :id
      String :name, null: false
      TrueClass :attending, default: true
      TrueClass :plus_one, default: false
      String :plus_one_name
      String :meal_choice
      String :plus_one_meal_choice
      Text :dietary_restrictions
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
