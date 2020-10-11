class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def create_or_update_track_file!(**track_args)
    TrackFile.where(user_id: id).first_or_initialize do |track_file|
      track_file.attributes = track_args
      track_file.save!
    end
  end
end
