Sequel.migration do
  change do
    create_table(:kids) do
      primary_key :id
      foreign_key :rsvp_id, :rsvps, null: false, on_delete: :cascade
      String :name, null: false
      String :meal_choice, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end

    add_index :kids, :rsvp_id
  end
end
