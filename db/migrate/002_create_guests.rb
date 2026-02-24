Sequel.migration do
  change do
    create_table(:guests) do
      primary_key :id
      String :name, null: false
      String :code, null: false, unique: true
      foreign_key :rsvp_id, :rsvps, null: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
