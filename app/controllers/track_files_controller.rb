class TrackFilesController < ApplicationController
  def update_current
    if current_user.create_or_update_track_file!(code_text: params[:file_text])
      render(json: {}, status: 200)
    else
      render(json: 'file could not be saved', status: :unprocessable_entity)
    end
  end

  def show_current
    current_track_text = current_user&.track_files.first&.code_text

    if current_track_text
      render(json: { file_text: current_track_text }.to_json, status: 200)
    else
      render(json: 'file could not be loaded', status: :unprocessable_entity)
    end
  end
end

