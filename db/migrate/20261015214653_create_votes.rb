class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :event, null: false, foreign_key: true
      t.string :user_id, null: false
      t.string :vote_type, null: false

      t.timestamps
    end

    add_index :votes, [ :event_id, :user_id ], unique: true
    add_check_constraint :votes, "vote_type IN ('upvote', 'downvote')", name: "votes_vote_type_check"
  end
end
