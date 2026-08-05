module Api
  module V1
    module Caregiver
      # Caregiver requirement #2 (post-M7 feedback round, ADR-0011): attach a
      # photo/video to a check-in already submitted via
      # `CheckInsController#create`/`#update`. A separate endpoint (rather
      # than folding the file into the check-in submission itself) keeps the
      # existing JSON check-in payload — and its IndexedDB offline-retry
      # queue (`offline-queue.ts`) — completely unchanged; the photo upload
      # is a best-effort second step the wizard fires after the check-in
      # itself is confirmed persisted.
      class CheckInPhotosController < ApplicationController
        include CaregiverAuthenticatable

        def create
          check_in = current_caregiver.episode.check_ins.find(params[:check_in_id])
          file = params[:image]

          return render json: { error: "missing_file" }, status: :unprocessable_content unless file

          photo = check_in.check_in_photos.new
          photo.image.attach(file)

          if photo.save
            Domain::Audit::Recorder.record!(
              actor: current_caregiver, action: "check_in_photo.attached", entity: check_in, payload: { photo_id: photo.id }
            )
            # Re-broadcast the check-in's activity payload now that it
            # carries a photo — the initial `check_in!` broadcast (fired at
            # submission time, before this follow-up upload) couldn't have
            # included it. Same type+id, so the cockpit's live feed
            # replaces the existing entry in place (see patient-detail.ts's
            # dedup-by-type-and-id) rather than duplicating it.
            check_in.check_in_photos.reload
            Domain::CareActivity::Broadcaster.check_in!(check_in)
            render json: { id: photo.id, url: Domain::Media::Url.for(photo.image), content_type: photo.image.content_type }, status: :created
          else
            render json: { errors: photo.errors.full_messages }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
