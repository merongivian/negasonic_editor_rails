class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :track_files

  def create_or_update_track_file!(**track_args)
    TrackFile.where(user_id: id).first_or_create.tap do |track_file|
      track_file.update_attributes! track_args
      track_file.save!
    end
  end
end
