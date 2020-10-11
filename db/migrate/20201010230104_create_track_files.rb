class CreateTrackFiles < ActiveRecord::Migration[5.2]
  def change
    create_table :track_files do |t|
      t.string :code_text, default: ''
      t.references :user, null: false
    end
  end
end
